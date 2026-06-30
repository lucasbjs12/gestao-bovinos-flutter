import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';

/// Verifica todos os bovinos ATIVOS com data de nascimento e promove a categoria
/// conforme a idade:
///
///   0  – 1 ano   →  Terneiro / Terneira  (sem mudança)
///   1  – 3 anos  →  Novilho  / Novilha
///   3+   anos    →  Touro    / Vaca
///
/// Roda silenciosamente a cada abertura do app.
class CategoriaProgressaoService {
  static const _msPerDay     = 86400000;
  static const _diasUmAno    = 365;
  static const _diasTresAnos = 1095;

  // Categorias que participam da progressão automática
  static const _categoriasMascara = {
    'Terneiro', 'Terneiro(a)', 'Terneira',
    'Novilho',  'Novilha',
  };

  /// Determina a nova categoria com base na categoria atual, sexo e idade.
  /// Retorna null se não houver mudança necessária.
  static String? _calcularNovaCategoria({
    required String? categoria,
    required String? sexo,
    required int idadeDias,
  }) {
    final cat     = categoria?.trim() ?? '';
    final eFemea  = (sexo?.trim() == 'Fêmea');

    // Terneiro / Terneira / Terneiro(a) → progressão pela idade
    if (cat == 'Terneiro' || cat == 'Terneira' || cat == 'Terneiro(a)') {
      if (idadeDias >= _diasTresAnos) return eFemea ? 'Vaca'    : 'Touro';
      if (idadeDias >= _diasUmAno)   return eFemea ? 'Novilha' : 'Novilho';
      return null; // ainda dentro do primeiro ano
    }

    // Novilha / Novilho → promove aos 3 anos completos
    if (cat == 'Novilha') {
      return idadeDias >= _diasTresAnos ? 'Vaca'  : null;
    }
    if (cat == 'Novilho') {
      return idadeDias >= _diasTresAnos ? 'Touro' : null;
    }

    return null; // Vaca, Touro, Boi, etc. — não alterar
  }

  /// Converte a string "dd/MM/yyyy" para milliseconds. Fallback quando
  /// dataNascimentoMillis não está preenchido (dados legados ou sync parcial).
  static int? _parseDataString(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      final p = s.split('/');
      if (p.length != 3) return null;
      return DateTime(
        int.parse(p[2]),
        int.parse(p[1]),
        int.parse(p[0]),
      ).millisecondsSinceEpoch;
    } catch (_) {
      return null;
    }
  }

  /// Executa a progressão. Retorna a lista de animais que foram promovidos.
  static Future<List<ProgressaoResultado>> executar({
    required String uid,
    required Database db,
  }) async {
    final agora     = DateTime.now().millisecondsSinceEpoch;
    final alterados = <ProgressaoResultado>[];

    // Busca somente animais ativos nas categorias elegíveis e com data de nascimento
    final categoriasSql = _categoriasMascara.map((_) => '?').join(', ');
    final rows = await db.rawQuery(
      '''
      SELECT id, syncId, numeroBrinco, categoria, sexo,
             dataNascimentoMillis, dataNascimento
      FROM   bovinos
      WHERE  LOWER(COALESCE(status, '')) = 'ativo'
        AND  categoria IN ($categoriasSql)
        AND  (dataNascimentoMillis IS NOT NULL OR dataNascimento IS NOT NULL)
      ''',
      _categoriasMascara.toList(),
    );

    for (final row in rows) {
      // Obtém millis da data de nascimento (campo ou fallback via string)
      final nascMs =
          (row['dataNascimentoMillis'] as int?) ??
          _parseDataString(row['dataNascimento'] as String?);

      if (nascMs == null) continue;

      final idadeDias = (agora - nascMs) ~/ _msPerDay;
      if (idadeDias < 0) continue; // data futura inválida

      final nova = _calcularNovaCategoria(
        categoria:  row['categoria'] as String?,
        sexo:       row['sexo']      as String?,
        idadeDias:  idadeDias,
      );
      if (nova == null) continue; // sem mudança

      final id     = row['id']          as int;
      final syncId = row['syncId']      as String?;
      final brinco = row['numeroBrinco'] as String? ?? '—';
      final catAnt = row['categoria']   as String? ?? '—';

      // 1) Atualiza SQLite
      await db.update(
        'bovinos',
        {'categoria': nova},
        where:     'id = ?',
        whereArgs: [id],
      );

      // 2) Espelha no Firestore (fire-and-forget; funciona offline)
      if (syncId != null && syncId.isNotEmpty) {
        FirebaseFirestore.instance
            .collection('fazendas')
            .doc(uid)
            .collection('bovinos')
            .doc(syncId)
            .set(
              {
                'categoria': nova,
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
      }

      alterados.add(
        ProgressaoResultado(
          brinco:            brinco,
          categoriaAnterior: catAnt,
          categoriaNova:     nova,
          idadeDias:         idadeDias,
        ),
      );
    }

    return alterados;
  }
}

class ProgressaoResultado {
  final String brinco;
  final String categoriaAnterior;
  final String categoriaNova;
  final int    idadeDias;

  const ProgressaoResultado({
    required this.brinco,
    required this.categoriaAnterior,
    required this.categoriaNova,
    required this.idadeDias,
  });

  int get anos  => idadeDias ~/ 365;
  int get meses => (idadeDias % 365) ~/ 30;
}
