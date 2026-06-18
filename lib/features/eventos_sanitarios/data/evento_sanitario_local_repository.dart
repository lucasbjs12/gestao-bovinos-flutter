import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../bovinos/data/bovino.dart';
import 'evento_sanitario.dart';
import 'evento_sanitario_completo.dart';

const _uuid = Uuid();

class EventoSanitarioLocalRepository {
  final Database _db;

  EventoSanitarioLocalRepository(this._db);

  static const _joinQuery = '''
    SELECT e.id, e.syncId, e.tipo, e.dataEvento, e.dataEventoMillis,
           e.invernadaId, i.descricao AS invernadaDescricao,
           e.produtoUtilizado, e.dosagem, e.responsavel, e.observacoes,
           GROUP_CONCAT(eb.bovinoId) AS bovinoIds,
           GROUP_CONCAT(COALESCE(b.nomeAnimal, b.numeroBrinco), ', ') AS bovinoNomes
    FROM eventos_sanitarios e
    LEFT JOIN invernadas i ON i.id = e.invernadaId
    LEFT JOIN evento_sanitario_bovino eb ON eb.eventoId = e.id
    LEFT JOIN bovinos b ON b.id = eb.bovinoId
  ''';

  Future<List<EventoSanitarioCompleto>> listar({
    String? tipo,
    String? termo,
    int? limit,
    int? offset,
  }) async {
    final where = <String>[];
    final args = <dynamic>[];

    if (tipo != null) {
      where.add('e.tipo = ?');
      args.add(tipo);
    }
    if (termo != null && termo.isNotEmpty) {
      where.add(
        "(e.tipo LIKE ? OR LOWER(COALESCE(e.produtoUtilizado,'')) LIKE ?"
        " OR LOWER(COALESCE(e.responsavel,'')) LIKE ?)",
      );
      final like = '%${termo.toLowerCase()}%';
      args.addAll([like, like, like]);
    }

    final whereClause =
        where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final pagination = [
      if (limit != null) 'LIMIT $limit',
      if (offset != null && offset > 0) 'OFFSET $offset',
    ].join(' ');

    final rows = await _db.rawQuery(
      '$_joinQuery $whereClause GROUP BY e.id '
      'ORDER BY e.dataEventoMillis DESC, e.id DESC $pagination',
      args,
    );
    return rows.map(EventoSanitarioCompleto.fromMap).toList();
  }

  Future<EventoSanitarioCompleto?> buscarCompletoPorId(int id) async {
    final rows = await _db.rawQuery(
      '$_joinQuery WHERE e.id = ? GROUP BY e.id',
      [id],
    );
    return rows.isEmpty ? null : EventoSanitarioCompleto.fromMap(rows.first);
  }

  Future<EventoSanitarioCompleto?> buscarCompletoPorSyncId(String syncId) async {
    final rows = await _db.rawQuery(
      '$_joinQuery WHERE e.syncId = ? GROUP BY e.id',
      [syncId],
    );
    return rows.isEmpty ? null : EventoSanitarioCompleto.fromMap(rows.first);
  }

  Future<List<EventoSanitarioCompleto>> listarPorBovino(int bovinoId) async {
    final rows = await _db.rawQuery(
      '$_joinQuery '
      'WHERE e.id IN ('
      '  SELECT eventoId FROM evento_sanitario_bovino WHERE bovinoId = ?'
      ') '
      'GROUP BY e.id '
      'ORDER BY e.dataEventoMillis DESC, e.id DESC',
      [bovinoId],
    );
    return rows.map(EventoSanitarioCompleto.fromMap).toList();
  }

  Future<List<Bovino>> listarBovinosDoEvento(int eventoId) async {
    final rows = await _db.rawQuery('''
      SELECT b.*, NULL AS invernadaDescricao
      FROM bovinos b
      JOIN evento_sanitario_bovino eb ON eb.bovinoId = b.id
      WHERE eb.eventoId = ?
      ORDER BY b.numeroBrinco COLLATE NOCASE
    ''', [eventoId]);
    return rows.map(Bovino.fromMap).toList();
  }

  Future<int> inserirComBovinos(
    EventoSanitario evento,
    List<int> bovinoIds,
  ) async {
    return _db.transaction((txn) async {
      final map = evento.toMap()..remove('id');
      final eventoId = await txn.insert('eventos_sanitarios', map);
      await _inserirVinculos(txn, eventoId, bovinoIds);
      return eventoId;
    });
  }

  Future<void> atualizarComBovinos(
    EventoSanitario evento,
    List<int> bovinoIds,
  ) async {
    await _db.transaction((txn) async {
      await txn.update(
        'eventos_sanitarios',
        evento.toMap(),
        where: 'id = ?',
        whereArgs: [evento.id],
      );
      await txn.delete(
        'evento_sanitario_bovino',
        where: 'eventoId = ?',
        whereArgs: [evento.id],
      );
      await _inserirVinculos(txn, evento.id!, bovinoIds);
    });
  }

  Future<void> excluir(int id) =>
      _db.delete('eventos_sanitarios', where: 'id = ?', whereArgs: [id]);

  /// Upsert por syncId — usado na sync inicial e em tempo real.
  Future<void> inserirOuSubstituirPorSyncId(
    EventoSanitario evento,
    List<int> bovinoIds,
  ) async {
    final existing = await buscarCompletoPorSyncId(evento.syncId);
    if (existing != null) {
      final updated = EventoSanitario(
        id: existing.id,
        syncId: evento.syncId,
        tipo: evento.tipo,
        dataEvento: evento.dataEvento,
        dataEventoMillis: evento.dataEventoMillis,
        invernadaId: evento.invernadaId,
        produtoUtilizado: evento.produtoUtilizado,
        dosagem: evento.dosagem,
        responsavel: evento.responsavel,
        observacoes: evento.observacoes,
      );
      await atualizarComBovinos(updated, bovinoIds);
    } else {
      final map = evento.toMap()..remove('id');
      await _db.transaction((txn) async {
        final eventoId = await txn.insert('eventos_sanitarios', map);
        await _inserirVinculos(txn, eventoId, bovinoIds);
      });
    }
  }

  Future<void> excluirPorSyncId(String syncId) =>
      _db.delete('eventos_sanitarios', where: 'syncId = ?', whereArgs: [syncId]);

  Future<void> _inserirVinculos(
    Transaction txn,
    int eventoId,
    List<int> bovinoIds,
  ) async {
    for (final bovinoId in bovinoIds) {
      await txn.insert(
        'evento_sanitario_bovino',
        {'eventoId': eventoId, 'bovinoId': bovinoId},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  /// Gera syncId para eventos existentes que ainda não têm (migração v1→v2).
  Future<void> preencherSyncIdsFaltantes() async {
    final rows = await _db.query(
      'eventos_sanitarios',
      columns: ['id'],
      where: 'syncId IS NULL',
    );
    for (final row in rows) {
      await _db.update(
        'eventos_sanitarios',
        {'syncId': _uuid.v4()},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }
}
