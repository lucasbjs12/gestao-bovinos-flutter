import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';

class DashboardStats {
  final int totalRebanho;
  final int vacas;
  final int novilhos;
  final int terneiros;
  final int outros;
  final int invernadas;
  final int baixados;
  final int semManejo;
  final int indefinidos;

  const DashboardStats({
    required this.totalRebanho,
    required this.vacas,
    required this.novilhos,
    required this.terneiros,
    required this.outros,
    required this.invernadas,
    required this.baixados,
    required this.semManejo,
    required this.indefinidos,
  });

  static const empty = DashboardStats(
    totalRebanho: 0, vacas: 0, novilhos: 0, terneiros: 0, outros: 0,
    invernadas: 0, baixados: 0, semManejo: 0, indefinidos: 0,
  );
}

class HomeProvider extends ChangeNotifier {
  DashboardStats _stats = DashboardStats.empty;
  bool _isLoading = false;

  DashboardStats get stats => _stats;
  bool get isLoading => _isLoading;

  Future<void> carregar(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await AppDatabase.instance.instanceFor(uid);

      // Contagem de bovinos ativos por categoria (rebanho)
      final catRows = await db.rawQuery(
        "SELECT LOWER(COALESCE(categoria,'')) AS cat, COUNT(*) AS cnt "
        "FROM bovinos WHERE LOWER(COALESCE(status,'')) != 'inativo' GROUP BY cat",
      );
      int total = 0, vacas = 0, novilhos = 0, terneiros = 0, outros = 0;
      for (final row in catRows) {
        final cat = row['cat'] as String? ?? '';
        final cnt = row['cnt'] as int? ?? 0;
        total += cnt;
        if (cat.startsWith('vaca')) {
          vacas += cnt;
        } else if (cat.startsWith('novilh')) {
          novilhos += cnt;
        } else if (cat.startsWith('ternei') || cat == 'terneiro(a)') {
          terneiros += cnt;
        } else {
          outros += cnt;
        }
      }

      // Contagem de invernadas
      final invRows = await db.rawQuery('SELECT COUNT(*) AS cnt FROM invernadas');
      final invCount = invRows.first['cnt'] as int? ?? 0;

      // Contagem de animais baixados
      final baixRows = await db.rawQuery(
        'SELECT COUNT(DISTINCT b.id) AS cnt FROM bovinos b '
        'INNER JOIN baixas_bovinos x ON x.bovinoId = b.id '
        "WHERE LOWER(COALESCE(b.status,'')) = 'inativo'",
      );
      final baixCount = baixRows.first['cnt'] as int? ?? 0;

      // Terneiros indefinidos (categoria genérica ainda não definida)
      final indRows = await db.rawQuery(
        "SELECT COUNT(*) AS cnt FROM bovinos WHERE categoria = 'Terneiro(a)' "
        "AND LOWER(COALESCE(status,'')) != 'inativo'",
      );
      final indCount = indRows.first['cnt'] as int? ?? 0;

      // Bovinos sem manejo sanitário nos últimos 30 dias (ou sem nenhum manejo)
      final cutoff = DateTime.now()
          .subtract(const Duration(days: 30))
          .millisecondsSinceEpoch;
      final manejoRows = await db.rawQuery(
        'SELECT COUNT(*) AS cnt FROM ('
        '  SELECT b.id, MAX(e.dataEventoMillis) AS ultimoMillis '
        '  FROM bovinos b '
        '  LEFT JOIN evento_sanitario_bovino eb ON eb.bovinoId = b.id '
        '  LEFT JOIN eventos_sanitarios e ON e.id = eb.eventoId '
        "  WHERE LOWER(COALESCE(b.status,'')) != 'inativo' "
        '  GROUP BY b.id '
        ') sub WHERE sub.ultimoMillis IS NULL OR sub.ultimoMillis < ?',
        [cutoff],
      );
      final semManejoCount = manejoRows.first['cnt'] as int? ?? 0;

      _stats = DashboardStats(
        totalRebanho: total,
        vacas: vacas,
        novilhos: novilhos,
        terneiros: terneiros,
        outros: outros,
        invernadas: invCount,
        baixados: baixCount,
        semManejo: semManejoCount,
        indefinidos: indCount,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
