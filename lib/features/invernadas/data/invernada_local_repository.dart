import 'package:sqflite/sqflite.dart';

import '../../bovinos/data/bovino.dart';
import 'invernada.dart';
import 'movimentacao_invernada.dart';

class InvernadaLocalRepository {
  final Database _db;

  InvernadaLocalRepository(this._db);

  // ── Invernadas ───────────────────────────────────────────────────────────

  Future<List<Invernada>> listar() async {
    final rows = await _db.rawQuery('''
      SELECT i.*,
        COUNT(b.id) AS quantidadeBovinos,
        GROUP_CONCAT(DISTINCT b.categoria) AS categoriasBovinos
      FROM invernadas i
      LEFT JOIN bovinos b ON b.invernadaId = i.id
        AND LOWER(COALESCE(b.status,'')) != 'inativo'
      GROUP BY i.id
      ORDER BY i.descricao ASC
    ''');
    return rows.map(Invernada.fromMap).toList();
  }

  Future<Invernada?> buscarPorId(int id) async {
    final rows = await _db.rawQuery('''
      SELECT i.*,
        COUNT(b.id) AS quantidadeBovinos,
        GROUP_CONCAT(DISTINCT b.categoria) AS categoriasBovinos
      FROM invernadas i
      LEFT JOIN bovinos b ON b.invernadaId = i.id
        AND LOWER(COALESCE(b.status,'')) != 'inativo'
      WHERE i.id = ?
      GROUP BY i.id
    ''', [id]);
    return rows.isEmpty ? null : Invernada.fromMap(rows.first);
  }

  Future<Invernada?> buscarPorSyncId(String syncId) async {
    final rows = await _db.rawQuery(
      'SELECT i.*, 0 AS quantidadeBovinos, NULL AS categoriasBovinos '
      'FROM invernadas i WHERE i.syncId = ?',
      [syncId],
    );
    return rows.isEmpty ? null : Invernada.fromMap(rows.first);
  }

  Future<int> inserir(Invernada i) => _db.insert('invernadas', i.toMap());

  Future<void> atualizar(Invernada i) => _db.update(
        'invernadas',
        i.toMap(),
        where: 'id = ?',
        whereArgs: [i.id],
      );

  /// Exclui a invernada. O FK SET NULL no schema já zera invernadaId dos bovinos.
  Future<void> excluir(int id) =>
      _db.delete('invernadas', where: 'id = ?', whereArgs: [id]);

  /// Retorna os bovinos que pertencem a esta invernada (para sincronizar após excluir).
  Future<List<Bovino>> listarBovinosDaInvernada(int invernadaId) async {
    final rows = await _db.rawQuery(
      'SELECT *, NULL AS invernadaDescricao FROM bovinos WHERE invernadaId = ?',
      [invernadaId],
    );
    return rows.map(Bovino.fromMap).toList();
  }

  Future<int> inserirOuSubstituirPorSyncId(Invernada i) async {
    final existing = await buscarPorSyncId(i.syncId);
    if (existing != null) {
      final m = i.toMap();
      m['id'] = existing.id;
      await _db.update('invernadas', m, where: 'id = ?', whereArgs: [existing.id]);
      return existing.id!;
    } else {
      final m = i.toMap()..remove('id');
      return await _db.insert('invernadas', m);
    }
  }

  Future<void> excluirPorSyncId(String syncId) =>
      _db.delete('invernadas', where: 'syncId = ?', whereArgs: [syncId]);

  /// Move [bovinoIds] para [novaInvernadaId] (null = sem invernada).
  /// Registra uma movimentação por bovino e retorna os bovinos atualizados.
  Future<List<Bovino>> moverBovinos({
    required List<int> bovinoIds,
    required int? novaInvernadaId,
  }) async {
    final agora = DateTime.now();
    final dataStr =
        '${agora.day.toString().padLeft(2, '0')}/'
        '${agora.month.toString().padLeft(2, '0')}/${agora.year}';
    final atualizados = <Bovino>[];

    await _db.transaction((txn) async {
      for (final id in bovinoIds) {
        final rows = await txn.rawQuery(
          'SELECT * FROM bovinos WHERE id = ?', [id]);
        if (rows.isEmpty) continue;
        final anteriorId = rows.first['invernadaId'] as int?;

        await txn.update(
          'bovinos', {'invernadaId': novaInvernadaId},
          where: 'id = ?', whereArgs: [id]);

        await txn.insert('movimentacoes_invernada', {
          'bovinoId': id,
          'data': dataStr,
          'dataMillis': agora.millisecondsSinceEpoch,
          'invernadaAnteriorId': anteriorId,
          'novaInvernadaId': novaInvernadaId,
        });

        final updated = await txn.rawQuery(
          'SELECT *, NULL AS invernadaDescricao, NULL AS ultimoManejoMillis '
          'FROM bovinos WHERE id = ?', [id]);
        if (updated.isNotEmpty) atualizados.add(Bovino.fromMap(updated.first));
      }
    });

    return atualizados;
  }

  // ── Movimentações ────────────────────────────────────────────────────────

  Future<int> inserirMovimentacao(MovimentacaoInvernada m) =>
      _db.insert('movimentacoes_invernada', m.toMap());

  Future<List<MovimentacaoResumo>> listarResumoPorInvernada(int invernadaId) async {
    final rows = await _db.rawQuery('''
      SELECT m.id, m.data, m.responsavel, m.observacoes,
        COALESCE(b.nomeAnimal, b.numeroBrinco) AS bovinoNome,
        ia.descricao AS invernadaAnterior,
        ib.descricao AS novaInvernada
      FROM movimentacoes_invernada m
      JOIN bovinos b ON b.id = m.bovinoId
      LEFT JOIN invernadas ia ON ia.id = m.invernadaAnteriorId
      LEFT JOIN invernadas ib ON ib.id = m.novaInvernadaId
      WHERE m.invernadaAnteriorId = ? OR m.novaInvernadaId = ?
      ORDER BY COALESCE(m.dataMillis, 0) DESC
    ''', [invernadaId, invernadaId]);
    return rows.map(MovimentacaoResumo.fromMap).toList();
  }
}
