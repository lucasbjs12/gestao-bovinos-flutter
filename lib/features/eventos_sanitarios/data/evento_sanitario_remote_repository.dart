import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/sync/sync_status_service.dart';
import 'evento_sanitario.dart';

class EventoSanitarioRemoteRepository {
  final String uid;
  final SyncStatusService _sync;
  final FirebaseFirestore _db;

  EventoSanitarioRemoteRepository({required this.uid, required this._sync})
      : _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('fazendas').doc(uid).collection('eventos_sanitarios');

  void salvar(EventoSanitario evento, List<int> bovinoIds) {
    _col.doc(evento.syncId).set({
      'id': evento.id,
      'syncId': evento.syncId,
      'tipo': evento.tipo,
      'dataEvento': evento.dataEvento,
      'dataEventoMillis': evento.dataEventoMillis,
      'invernadaId': evento.invernadaId,
      'produtoUtilizado': evento.produtoUtilizado,
      'dosagem': evento.dosagem,
      'responsavel': evento.responsavel,
      'observacoes': evento.observacoes,
      'bovinoIds': bovinoIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _sync.notificarEscrita();
  }

  void excluir(String syncId) {
    _col.doc(syncId).delete();
    _sync.notificarEscrita();
  }
}
