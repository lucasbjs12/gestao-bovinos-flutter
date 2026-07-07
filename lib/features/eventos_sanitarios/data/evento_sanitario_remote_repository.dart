import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/db/app_database.dart';
import '../../../core/sync/sync_refs.dart';
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

  Future<void> salvar(EventoSanitario evento, List<int> bovinoIds) async {
    // Referências viajam como syncId (global); os ids locais continuam no doc
    // apenas para compatibilidade com versões antigas do app.
    final db = await AppDatabase.instance.instanceFor(uid);
    final bovinoSyncIds = await SyncRefs.syncIdsDeBovinos(db, bovinoIds);
    final invernadaSyncId =
        await SyncRefs.syncIdPorId(db, 'invernadas', evento.invernadaId);

    _col.doc(evento.syncId).set({
      'id': evento.id,
      'syncId': evento.syncId,
      'tipo': evento.tipo,
      'dataEvento': evento.dataEvento,
      'dataEventoMillis': evento.dataEventoMillis,
      'invernadaId': evento.invernadaId,
      'invernadaSyncId': invernadaSyncId,
      'produtoUtilizado': evento.produtoUtilizado,
      'dosagem': evento.dosagem,
      'responsavel': evento.responsavel,
      'observacoes': evento.observacoes,
      'bovinoIds': bovinoIds,
      'bovinoSyncIds': bovinoSyncIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _sync.notificarEscrita();
  }

  void excluir(String syncId) {
    _col.doc(syncId).delete();
    _sync.notificarEscrita();
  }
}
