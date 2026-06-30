import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/sync/sync_status_service.dart';
import 'bovino.dart';

/// Espelha cada operação no Cloud Firestore (fire-and-forget / local-first).
///
/// O SDK do Firestore enfileira as escritas offline e as envia quando a
/// conexão volta — sem nenhuma lógica adicional aqui.
class BovinoRemoteRepository {
  final String uid;
  final SyncStatusService _sync;
  final FirebaseFirestore _db;

  BovinoRemoteRepository({required this.uid, required this._sync})
      : _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('fazendas').doc(uid).collection('bovinos');

  void salvar(Bovino b) {
    _col.doc(b.syncId).set({
      'id': b.id,
      'syncId': b.syncId,
      'numeroBrinco': b.numeroBrinco,
      'nomeAnimal': b.nomeAnimal,
      'codigoEpc': b.codigoEpc,
      'codigoInterno': b.codigoInterno,
      'raca': b.raca,
      'dataNascimento': b.dataNascimento,
      'dataNascimentoMillis': b.dataNascimentoMillis,
      'pesoAtualKg': b.pesoAtualKg,
      'pelagem': b.pelagem,
      'sexo': b.sexo,
      'categoria': b.categoria,
      'status': b.status,
      'origem': b.origem,
      'observacoes': b.observacoes,
      'foto': b.foto,
      'invernadaId': b.invernadaId,
      'idMae': b.idMae,
      'estaDeCria': b.estaDeCria == 1,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _sync.notificarEscrita();
  }

  void excluir(String syncId) {
    _col.doc(syncId).delete();
    _sync.notificarEscrita();
  }
}
