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
    final result = <String>[];
    for (final id in ids) {
      final s = await syncIdPorId(db, 'bovinos', id);
      if (s != null) result.add(s);
    }
    return result;
  }

  /// Lista de bovinos de um evento vinda da nuvem: bovinoSyncIds (novo) tem
  /// prioridade; bovinoIds legados valem apenas se existirem localmente.
  static Future<List<int>> idsDeBovinosRemotos(
    Database db, {
    required List<String> syncIds,
    required List<int> legacyIds,
  }) async {
    if (syncIds.isNotEmpty) {
      final result = <int>[];
      for (final s in syncIds) {
        final id = await idPorSyncId(db, 'bovinos', s);
        if (id != null) result.add(id);
      }
      return result;
    }
    final result = <int>[];
    for (final id in legacyIds) {
      final rows = await db.query(
        'bovinos',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isNotEmpty) result.add(id);
    }
    return result;
  }
}
