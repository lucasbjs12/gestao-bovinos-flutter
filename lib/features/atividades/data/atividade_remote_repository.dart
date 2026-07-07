import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/sync/sync_status_service.dart';
import 'atividade.dart';

/// Espelha o diário de atividades no Cloud Firestore (fire-and-forget).
class AtividadeRemoteRepository {
  final String uid;
  final SyncStatusService _sync;
  final FirebaseFirestore _db;

  AtividadeRemoteRepository({required this.uid, required this._sync})
      : _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('fazendas').doc(uid).collection('atividades');

  void salvar(Atividade a) {
    _col.doc(a.syncId).set({
      'syncId': a.syncId,
      'autorUid': a.autorUid,
      'autorNome': a.autorNome,
      'acao': a.acao,
      'descricao': a.descricao,
      'dataMillis': a.dataMillis,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _sync.notificarEscrita();
  }
}
