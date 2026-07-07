import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/db/app_database.dart';
import '../../../core/sync/sync_refs.dart';
import '../../../core/sync/sync_status_service.dart';
import '../../atividades/atividade_service.dart';
import '../../bovinos/data/bovino.dart';
import '../../bovinos/data/bovino_remote_repository.dart';
import 'invernada.dart';
import 'movimentacao_invernada.dart';

class InvernadaRemoteRepository {
  final String uid;
  final SyncStatusService _sync;
  final FirebaseFirestore _db;

  InvernadaRemoteRepository({required this.uid, required this._sync})
      : _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('fazendas').doc(uid).collection('invernadas');

  CollectionReference<Map<String, dynamic>> get _colMov =>
      _db.collection('fazendas').doc(uid).collection('movimentacoes');

  void salvar(Invernada i) {
    _col.doc(i.syncId).set({
      'id': i.id,
      'syncId': i.syncId,
      'descricao': i.descricao,
      'hectares': i.hectares,
      'urlFoto': i.urlFoto,
      'observacoes': i.observacoes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _sync.notificarEscrita();
    AtividadeService.registrar(
      uid: uid,
      sync: _sync,
      acao: 'invernada_salva',
      descricao: 'Salvou a invernada ${i.descricao}',
    );
  }

  /// Exclui a invernada e re-salva os bovinos afetados com invernadaId = null.
  void excluirComBovinos(String syncId, List<Bovino> bovinosAfetados) {
    _col.doc(syncId).delete();
    final bovinoRepo = BovinoRemoteRepository(uid: uid, sync: _sync);
    for (final b in bovinosAfetados) {
      // efeito colateral da exclusão — não polui o diário
      bovinoRepo.salvar(b, registrarAtividade: false);
    }
    _sync.notificarEscrita();
    AtividadeService.registrar(
      uid: uid,
      sync: _sync,
      acao: 'invernada_excluida',
      descricao: 'Excluiu uma invernada '
          '(${bovinosAfetados.length} animais ficaram sem invernada)',
    );
  }

  Future<void> salvarMovimentacao(MovimentacaoInvernada m, int localId) async {
    final db = await AppDatabase.instance.instanceFor(uid);
    final bovinoSyncId = await SyncRefs.syncIdPorId(db, 'bovinos', m.bovinoId);
    final anteriorSyncId =
        await SyncRefs.syncIdPorId(db, 'invernadas', m.invernadaAnteriorId);
    final novaSyncId =
        await SyncRefs.syncIdPorId(db, 'invernadas', m.novaInvernadaId);

    _colMov.doc(localId.toString()).set({
      'id': localId,
      'bovinoId': m.bovinoId,
      'bovinoSyncId': bovinoSyncId,
      'data': m.data,
      'invernadaAnteriorId': m.invernadaAnteriorId,
      'invernadaAnteriorSyncId': anteriorSyncId,
      'novaInvernadaId': m.novaInvernadaId,
      'novaInvernadaSyncId': novaSyncId,
      'responsavel': m.responsavel,
      'observacoes': m.observacoes,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _sync.notificarEscrita();

    final brincoRows = await db.query(
      'bovinos',
      columns: ['numeroBrinco'],
      where: 'id = ?',
      whereArgs: [m.bovinoId],
    );
    final destinoRows = await db.query(
      'invernadas',
      columns: ['descricao'],
      where: 'id = ?',
      whereArgs: [m.novaInvernadaId],
    );
    final brinco = brincoRows.isEmpty
        ? 'um bovino'
        : 'o brinco ${brincoRows.first['numeroBrinco']}';
    final destino = destinoRows.isEmpty
        ? 'sem invernada'
        : '${destinoRows.first['descricao']}';
    await AtividadeService.registrar(
      uid: uid,
      sync: _sync,
      acao: 'movimentacao',
      descricao: 'Moveu $brinco para $destino',
    );
  }
}
