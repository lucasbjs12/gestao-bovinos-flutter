import 'package:sqflite/sqflite.dart';

/// Tradução entre ids locais (AUTOINCREMENT, válidos só neste aparelho) e
/// syncIds (UUIDs globais) na subida e na descida do sync.
///
/// Docs antigos no Firestore carregam apenas o id local do aparelho de
/// origem; o fallback `legacyId` preserva o comportamento anterior para
/// esses documentos até serem regravados com syncIds.
class SyncRefs {
  static Future<String?> syncIdPorId(Database db, String tabela, int? id) async {
    if (id == null) return null;
    final rows = await db.query(
      tabela,
      columns: ['syncId'],
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : rows.first['syncId'] as String?;
  }

  static Future<int?> idPorSyncId(Database db, String tabela, String? syncId) async {
    if (syncId == null || syncId.isEmpty) return null;
    final rows = await db.query(
      tabela,
      columns: ['id'],
      where: 'syncId = ?',
      whereArgs: [syncId],
    );
    return rows.isEmpty ? null : rows.first['id'] as int?;
  }

  /// Versão em lote de [idPorSyncId]: uma única query `WHERE syncId IN (...)`
  /// em vez de uma query por item -- usada nos loops de sync pra evitar N+1.
  static Future<Map<String, int>> idsPorSyncIds(
    Database db,
    String tabela,
    Iterable<String> syncIds,
  ) async {
    final unicos = syncIds.toSet().toList();
    if (unicos.isEmpty) return {};
    final result = <String, int>{};
    // SQLite tem limite de variáveis por statement -- processa em blocos.
    for (var i = 0; i < unicos.length; i += 500) {
      final bloco = unicos.sublist(i, i + 500 > unicos.length ? unicos.length : i + 500);
      final placeholders = List.filled(bloco.length, '?').join(',');
      final rows = await db.query(
        tabela,
        columns: ['id', 'syncId'],
        where: 'syncId IN ($placeholders)',
        whereArgs: bloco,
      );
      for (final r in rows) {
        result[r['syncId'] as String] = r['id'] as int;
      }
    }
    return result;
  }

  /// Versão em lote de [syncIdPorId].
  static Future<Map<int, String>> syncIdsPorIds(
    Database db,
    String tabela,
    Iterable<int> ids,
  ) async {
    final unicos = ids.toSet().toList();
    if (unicos.isEmpty) return {};
    final result = <int, String>{};
    for (var i = 0; i < unicos.length; i += 500) {
      final bloco = unicos.sublist(i, i + 500 > unicos.length ? unicos.length : i + 500);
      final placeholders = List.filled(bloco.length, '?').join(',');
      final rows = await db.query(
        tabela,
        columns: ['id', 'syncId'],
        where: 'id IN ($placeholders)',
        whereArgs: bloco,
      );
      for (final r in rows) {
        result[r['id'] as int] = r['syncId'] as String;
      }
    }
    return result;
  }

  /// Resolve uma referência vinda da nuvem. Se o doc traz syncId, ele manda
  /// (não resolvido localmente = null — nunca cai num id legado de outro
  /// aparelho); sem syncId, usa o id legado como antes.
  static Future<int?> idRemotoResolvido(
    Database db,
    String tabela, {
    String? syncId,
    int? legacyId,
  }) async {
    if (syncId != null && syncId.isNotEmpty) {
      return idPorSyncId(db, tabela, syncId);
    }
    return legacyId;
  }

  static Future<List<String>> syncIdsDeBovinos(Database db, List<int> ids) async {
    final mapa = await syncIdsPorIds(db, 'bovinos', ids);
    return [for (final id in ids) if (mapa[id] != null) mapa[id]!];
  }

  /// Lista de bovinos de um evento vinda da nuvem: bovinoSyncIds (novo) tem
  /// prioridade; bovinoIds legados valem apenas se existirem localmente.
  static Future<List<int>> idsDeBovinosRemotos(
    Database db, {
    required List<String> syncIds,
    required List<int> legacyIds,
  }) async {
    if (syncIds.isNotEmpty) {
      final mapa = await idsPorSyncIds(db, 'bovinos', syncIds);
      return [for (final s in syncIds) if (mapa[s] != null) mapa[s]!];
    }
    final mapa = await syncIdsPorIds(db, 'bovinos', legacyIds);
    return [for (final id in legacyIds) if (mapa.containsKey(id)) id];
  }
}
