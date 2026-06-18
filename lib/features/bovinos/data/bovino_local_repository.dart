import 'package:sqflite/sqflite.dart';

import 'baixa_bovino.dart';
import 'bovino.dart';

class BovinoLocalRepository {
  final Database _db;

  BovinoLocalRepository(this._db);

  Future<List<Bovino>> listarAtivos({
    String? termo,
    String? categoria,
    int? limit,
    int? offset,
    BovinoOrdem ordem = BovinoOrdem.brinco,
  }) async {
    final where = <String>["LOWER(COALESCE(b.status,'')) != 'inativo'"];
    final args = <dynamic>[];

    if (termo != null && termo.isNotEmpty) {
      where.add(
        "(b.numeroBrinco LIKE ? OR LOWER(COALESCE(b.nomeAnimal,'')) LIKE ?)",
      );
      final like = '%${termo.toLowerCase()}%';
      args.addAll([like, like]);
    }

    if (categoria != null) {
      where.add('LOWER(b.categoria) = ?');
      args.add(categoria.toLowerCase());
    }

    final pagination = [
      if (limit != null) 'LIMIT $limit',
      if (offset != null && offset > 0) 'OFFSET $offset',
    ].join(' ');

    final orderBy = switch (ordem) {
      BovinoOrdem.brinco    => 'b.numeroBrinco ASC',
      BovinoOrdem.nome      => 'LOWER(COALESCE(b.nomeAnimal, b.numeroBrinco)) ASC',
      BovinoOrdem.categoria => 'b.categoria ASC, b.numeroBrinco ASC',
      BovinoOrdem.invernada => 'LOWER(COALESCE(i.descricao,"")), b.numeroBrinco ASC',
      BovinoOrdem.peso      => 'b.pesoAtualKg DESC NULLS LAST, b.numeroBrinco ASC',
    };

    final sql =
        'SELECT b.*, i.descricao AS invernadaDescricao '
        'FROM bovinos b '
        'LEFT JOIN invernadas i ON b.invernadaId = i.id '
        'WHERE ${where.join(' AND ')} '
        'ORDER BY $orderBy $pagination';

    final rows = await _db.rawQuery(sql, args);
    return rows.map(Bovino.fromMap).toList();
  }

  Future<Bovino?> buscarPorId(int id) async {
    final rows = await _db.rawQuery(
      'SELECT b.*, i.descricao AS invernadaDescricao '
      'FROM bovinos b '
      'LEFT JOIN invernadas i ON b.invernadaId = i.id '
      'WHERE b.id = ?',
      [id],
    );
    return rows.isEmpty ? null : Bovino.fromMap(rows.first);
  }

  Future<bool> brincoEmUso(String brinco, {int? excluirId}) async {
    final whereStr =
        excluirId != null ? 'numeroBrinco = ? AND id != ?' : 'numeroBrinco = ?';
    final args = excluirId != null ? [brinco, excluirId] : [brinco];
    final count = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM bovinos WHERE $whereStr', args),
    ) ?? 0;
    return count > 0;
  }

  Future<Bovino?> buscarFilhoPorMae(int maeId) async {
    final rows = await _db.rawQuery(
      'SELECT b.*, i.descricao AS invernadaDescricao '
      'FROM bovinos b '
      'LEFT JOIN invernadas i ON b.invernadaId = i.id '
      "WHERE b.idMae = ? AND LOWER(COALESCE(b.status,'')) != 'inativo' "
      'LIMIT 1',
      [maeId],
    );
    return rows.isEmpty ? null : Bovino.fromMap(rows.first);
  }

  Future<Bovino?> buscarPorBrincoExato(String brinco) async {
    final rows = await _db.rawQuery(
      'SELECT b.*, i.descricao AS invernadaDescricao '
      'FROM bovinos b '
      'LEFT JOIN invernadas i ON b.invernadaId = i.id '
      "WHERE b.numeroBrinco = ? AND LOWER(COALESCE(b.status,'')) != 'inativo' "
      'LIMIT 1',
      [brinco],
    );
    return rows.isEmpty ? null : Bovino.fromMap(rows.first);
  }

  Future<void> vincularTerneiro(int terneiroId, int maeId) =>
      _db.update('bovinos', {'idMae': maeId}, where: 'id = ?', whereArgs: [terneiroId]);

  Future<void> desvincularTerneiro(int terneiroId) =>
      _db.rawUpdate('UPDATE bovinos SET idMae = NULL WHERE id = ?', [terneiroId]);

  /// Cria terneiro mínimo herdando raça, invernada, origem e pelagem da mãe.
  Future<Bovino> criarTerneiroVinculado({
    required String numeroBrinco,
    required Bovino mae,
  }) async {
    final mapa = Bovino.criar(numeroBrinco: numeroBrinco).toMap()
      ..addAll({
        'idMae': mae.id,
        'raca': mae.raca,
        'invernadaId': mae.invernadaId,
        'origem': mae.origem,
        'pelagem': mae.pelagem,
        'categoria': 'Terneiro(a)',
      });
    final newId = await _db.insert('bovinos', mapa);
    return Bovino.fromMap({...mapa, 'id': newId, 'invernadaDescricao': mae.invernadaDescricao});
  }

  Future<Bovino?> buscarPorSyncId(String syncId) async {
    final rows = await _db.rawQuery(
      'SELECT b.*, i.descricao AS invernadaDescricao '
      'FROM bovinos b '
      'LEFT JOIN invernadas i ON b.invernadaId = i.id '
      'WHERE b.syncId = ?',
      [syncId],
    );
    return rows.isEmpty ? null : Bovino.fromMap(rows.first);
  }

  /// Upsert por syncId: atualiza se já existe localmente, insere caso contrário.
  Future<int> inserirOuSubstituirPorSyncId(Bovino b) async {
    final existing = await buscarPorSyncId(b.syncId);
    if (existing != null) {
      final m = b.toMap();
      m['id'] = existing.id;
      await _db.update('bovinos', m, where: 'id = ?', whereArgs: [existing.id]);
      return existing.id!;
    } else {
      final m = b.toMap()..remove('id');
      return await _db.insert('bovinos', m);
    }
  }

  Future<void> excluirPorSyncId(String syncId) =>
      _db.delete('bovinos', where: 'syncId = ?', whereArgs: [syncId]);

  Future<void> atualizarIdMaePorSyncId(String syncId, int idMae) =>
      _db.rawUpdate(
        'UPDATE bovinos SET idMae = ? WHERE syncId = ?',
        [idMae, syncId],
      );

  Future<int> inserir(Bovino b) => _db.insert('bovinos', b.toMap());

  Future<void> atualizar(Bovino b) => _db.update(
        'bovinos',
        b.toMap(),
        where: 'id = ?',
        whereArgs: [b.id],
      );

  Future<void> excluir(int id) =>
      _db.delete('bovinos', where: 'id = ?', whereArgs: [id]);

  // ── Métodos derivados ─────────────────────────────────────────────────────

  /// Retorna bovinos ativos com o timestamp do último manejo sanitário.
  Future<List<BovinoResumoManejo>> listarComUltimoManejo() async {
    final rows = await _db.rawQuery('''
      SELECT b.id, b.syncId, b.numeroBrinco, b.nomeAnimal, b.categoria,
             b.invernadaId, i.descricao AS invernadaDescricao,
             MAX(e.dataEventoMillis) AS ultimoManejoMillis
      FROM bovinos b
      LEFT JOIN invernadas i ON i.id = b.invernadaId
      LEFT JOIN evento_sanitario_bovino eb ON eb.bovinoId = b.id
      LEFT JOIN eventos_sanitarios e ON e.id = eb.eventoId
      WHERE LOWER(COALESCE(b.status, '')) != 'inativo'
      GROUP BY b.id
      ORDER BY CASE WHEN MAX(e.dataEventoMillis) IS NULL THEN 0 ELSE 1 END ASC,
               MAX(e.dataEventoMillis) ASC,
               b.numeroBrinco COLLATE NOCASE ASC
    ''');
    return rows.map(BovinoResumoManejo.fromMap).toList();
  }

  /// Retorna terneiros com categoria genérica 'Terneiro(a)' e status ativo.
  Future<List<Bovino>> listarTerneirosIndefinidos() async {
    final rows = await _db.rawQuery('''
      SELECT b.*, i.descricao AS invernadaDescricao
      FROM bovinos b
      LEFT JOIN invernadas i ON i.id = b.invernadaId
      WHERE b.categoria = 'Terneiro(a)' AND LOWER(COALESCE(b.status, '')) != 'inativo'
      ORDER BY b.numeroBrinco COLLATE NOCASE ASC
    ''');
    return rows.map(Bovino.fromMap).toList();
  }

  /// Retorna bovinos com status 'inativo', enriquecidos com dados da baixa.
  Future<List<BovinoBaixado>> listarBaixados() async {
    final rows = await _db.rawQuery('''
      SELECT b.id, b.syncId, b.numeroBrinco, b.nomeAnimal, b.categoria, b.raca, b.foto,
             x.id AS baixaId, x.motivo, x.dataBaixa, x.dataBaixaMillis,
             x.observacoes AS observacoesBaixa
      FROM bovinos b
      INNER JOIN baixas_bovinos x ON x.bovinoId = b.id
      WHERE LOWER(COALESCE(b.status, '')) = 'inativo'
      GROUP BY b.id
      ORDER BY x.dataBaixaMillis DESC, b.id DESC
    ''');
    return rows.map(BovinoBaixado.fromMap).toList();
  }

  /// Transação: insere baixa + marca bovino como Inativo + limpa estaDeCria da mãe.
  Future<Bovino> darBaixaBovino({
    required int id,
    required String motivo,
    required String dataBaixa,
    required int dataBaixaMillis,
    String? observacoes,
  }) async {
    return _db.transaction((txn) async {
      final existingRows = await txn.rawQuery(
        'SELECT * FROM bovinos WHERE id = ?',
        [id],
      );
      final existing = existingRows.first;

      await txn.insert('baixas_bovinos', {
        'bovinoId': id,
        'motivo': motivo,
        'dataBaixa': dataBaixa,
        'dataBaixaMillis': dataBaixaMillis,
        'observacoes': observacoes,
      });

      await txn.update(
        'bovinos',
        {'status': 'Inativo'},
        where: 'id = ?',
        whereArgs: [id],
      );

      final idMae = existing['idMae'];
      if (idMae != null) {
        await txn.update(
          'bovinos',
          {'estaDeCria': 0},
          where: 'id = ?',
          whereArgs: [idMae],
        );
      }

      final updated = await txn.rawQuery(
        'SELECT *, NULL AS invernadaDescricao FROM bovinos WHERE id = ?',
        [id],
      );
      return Bovino.fromMap(updated.first);
    });
  }

  /// Transação: reverte bovino para Ativo + remove todas as baixas do bovino.
  Future<Bovino> reativarBovino(int id) async {
    return _db.transaction((txn) async {
      await txn.update(
        'bovinos',
        {'status': 'Ativo'},
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.delete('baixas_bovinos', where: 'bovinoId = ?', whereArgs: [id]);
      final rows = await txn.rawQuery(
        'SELECT *, NULL AS invernadaDescricao FROM bovinos WHERE id = ?',
        [id],
      );
      return Bovino.fromMap(rows.first);
    });
  }
}
