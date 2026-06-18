import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/sync/sync_status_service.dart';
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
      'urlFoto': i.urlFoto,
      'observacoes': i.observacoes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _sync.notificarEscrita();
  }

  /// Exclui a invernada e re-salva os bovinos afetados com invernadaId = null.
  void excluirComBovinos(String syncId, List<Bovino> bovinosAfetados) {
    _col.doc(syncId).delete();
    final bovinoRepo = BovinoRemoteRepository(uid: uid, sync: _sync);
    for (final b in bovinosAfetados) {
      bovinoRepo.salvar(b);
    }
    _sync.notificarEscrita();
  }

  void salvarMovimentacao(MovimentacaoInvernada m, int localId) {
    _colMov.doc(localId.toString()).set({
      'id': localId,
      'bovinoId': m.bovinoId,
      'data': m.data,
      'invernadaAnteriorId': m.invernadaAnteriorId,
      'novaInvernadaId': m.novaInvernadaId,
      'responsavel': m.responsavel,
      'observacoes': m.observacoes,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _sync.notificarEscrita();
  }
}
