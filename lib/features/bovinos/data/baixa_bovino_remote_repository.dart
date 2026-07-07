import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/sync/sync_status_service.dart';
import '../../atividades/atividade_service.dart';
import 'baixa_bovino.dart';
import 'bovino.dart';

/// Espelha baixas e reativações no Cloud Firestore (fire-and-forget).
class BaixaBovinoRemoteRepository {
  final String uid;
  final SyncStatusService _syncSvc;
  final FirebaseFirestore _fs;

  BaixaBovinoRemoteRepository({required this.uid, required SyncStatusService sync})
      : _syncSvc = sync, _fs = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _bovinoCol =>
      _fs.collection('fazendas').doc(uid).collection('bovinos');

  CollectionReference<Map<String, dynamic>> get _baixaCol =>
      _fs.collection('fazendas').doc(uid).collection('baixas_bovinos');

  void darBaixa(Bovino bovino, BaixaBovino baixa) {
    // Atualiza status do bovino
    _bovinoCol.doc(bovino.syncId).set(
      {'status': 'Inativo', 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    // Grava registro da baixa (chave = id local do bovino, 1 baixa ativa por animal)
    _baixaCol.doc(bovino.id.toString()).set({
      'bovinoId': baixa.bovinoId,
      'bovinoSyncId': bovino.syncId,
      'motivo': baixa.motivo,
      'dataBaixa': baixa.dataBaixa,
      'dataBaixaMillis': baixa.dataBaixaMillis,
      if (baixa.observacoes != null) 'observacoes': baixa.observacoes,
    });
    _syncSvc.notificarEscrita();
    AtividadeService.registrar(
      uid: uid,
      sync: _syncSvc,
      acao: 'baixa',
      descricao: 'Deu baixa no bovino ${bovino.numeroBrinco} — ${baixa.motivo}',
    );
  }

  void reativar(Bovino bovino) {
    _bovinoCol.doc(bovino.syncId).set(
      {'status': 'Ativo', 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    _baixaCol.doc(bovino.id.toString()).delete();
    _syncSvc.notificarEscrita();
    AtividadeService.registrar(
      uid: uid,
      sync: _syncSvc,
      acao: 'reativacao',
      descricao: 'Reativou o bovino ${bovino.numeroBrinco}',
    );
  }

  void excluirPermanente({required String syncId, required int bovinoId}) {
    _bovinoCol.doc(syncId).delete();
    _baixaCol.doc(bovinoId.toString()).delete();
    _syncSvc.notificarEscrita();
    AtividadeService.registrar(
      uid: uid,
      sync: _syncSvc,
      acao: 'bovino_excluido',
      descricao: 'Excluiu permanentemente um bovino baixado',
    );
  }
}
