import 'package:sqflite/sqflite.dart';

import 'atividade.dart';

class AtividadeLocalRepository {
  final Database _db;

  AtividadeLocalRepository(this._db);

  Future<int> inserir(Atividade a) async {
    final m = a.toMap()..remove('id');
    return _db.insert('atividades', m);
  }

  Future<List<Atividade>> listar({int? limit, int? offset}) async {
    final rows = await _db.query(
      'atividades',
      orderBy: 'dataMillis DESC, id DESC',
      limit: limit,
      offset: (offset != null && offset > 0) ? offset : null,
    );
    return rows.map(Atividade.fromMap).toList();
  }

  Future<Atividade?> buscarPorSyncId(String syncId) async {
    final rows = await _db.query(
      'atividades',
      where: 'syncId = ?',
      whereArgs: [syncId],
      limit: 1,
    );
    return rows.isEmpty ? null : Atividade.fromMap(rows.first);
  }

  /// Upsert por syncId — usado na sync inicial e em tempo real.
  Future<void> inserirOuSubstituirPorSyncId(Atividade a) async {
    final existing = await buscarPorSyncId(a.syncId);
    if (existing != null) {
      final m = a.toMap();
      m['id'] = existing.id;
      await _db.update('atividades', m, where: 'id = ?', whereArgs: [existing.id]);
    } else {
      await inserir(a);
    }
  }

  Future<void> excluirPorSyncId(String syncId) =>
      _db.delete('atividades', where: 'syncId = ?', whereArgs: [syncId]);
}
