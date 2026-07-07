import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';

import '../core/sync/sync_refs.dart';
import '../features/atividades/data/atividade.dart';
import '../features/atividades/data/atividade_local_repository.dart';
import '../features/bovinos/data/bovino.dart';
import '../features/bovinos/data/bovino_local_repository.dart';
import '../features/eventos_sanitarios/data/evento_sanitario.dart';
import '../features/eventos_sanitarios/data/evento_sanitario_local_repository.dart';
import '../features/invernadas/data/invernada.dart';
import '../features/invernadas/data/invernada_local_repository.dart';

/// Escuta as coleções `invernadas`, `bovinos` e `eventos_sanitarios` do Firestore
/// e aplica as mudanças no sqflite local (sem loop: listeners só escrevem no sqflite).
class RealtimeSyncService {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _invernadasSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _bovinosSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _eventosSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _atividadesSub;

  void start({required String uid, required Database db}) {
    if (_bovinosSub != null) return; // idempotente

    final fazenda = FirebaseFirestore.instance.collection('fazendas').doc(uid);

    _invernadasSub =
        fazenda.collection('invernadas').snapshots().listen((snap) async {
      final repo = InvernadaLocalRepository(db);
      for (final change in snap.docChanges) {
        if (change.doc.metadata.hasPendingWrites) continue;
        try {
          if (change.type == DocumentChangeType.removed) {
            await repo.excluirPorSyncId(change.doc.id);
          } else {
            await repo.inserirOuSubstituirPorSyncId(_invernadaFromDoc(change.doc));
          }
        } catch (_) {}
      }
    });

    _bovinosSub = fazenda.collection('bovinos').snapshots().listen((snap) async {
      final repo = BovinoLocalRepository(db);
      for (final change in snap.docChanges) {
        if (change.doc.metadata.hasPendingWrites) continue;
        try {
          if (change.type == DocumentChangeType.removed) {
            await repo.excluirPorSyncId(change.doc.id);
          } else {
            await repo.inserirOuSubstituirPorSyncId(
              await _bovinoFromDoc(db, change.doc),
            );
          }
        } catch (_) {}
      }
    });

    _eventosSub =
        fazenda.collection('eventos_sanitarios').snapshots().listen((snap) async {
      final repo = EventoSanitarioLocalRepository(db);
      for (final change in snap.docChanges) {
        if (change.doc.metadata.hasPendingWrites) continue;
        try {
          if (change.type == DocumentChangeType.removed) {
            await repo.excluirPorSyncId(change.doc.id);
          } else {
            final d = change.doc.data()!;
            final bovinoIds = await SyncRefs.idsDeBovinosRemotos(
              db,
              syncIds: _listaStringOuVazia(d['bovinoSyncIds']),
              legacyIds: _listaIntOuVazia(d['bovinoIds']),
            );
            final evento = await _eventoFromDoc(db, change.doc);
            await repo.inserirOuSubstituirPorSyncId(evento, bovinoIds);
          }
        } catch (_) {}
      }
    });

    _atividadesSub =
        fazenda.collection('atividades').snapshots().listen((snap) async {
      final repo = AtividadeLocalRepository(db);
      for (final change in snap.docChanges) {
        if (change.doc.metadata.hasPendingWrites) continue;
        try {
          if (change.type == DocumentChangeType.removed) {
            await repo.excluirPorSyncId(change.doc.id);
          } else {
            final d = change.doc.data()!;
            await repo.inserirOuSubstituirPorSyncId(
              Atividade.fromMap({...d, 'syncId': change.doc.id, 'id': null}),
            );
          }
        } catch (_) {}
      }
    });
  }

  void stop() {
    _invernadasSub?.cancel();
    _invernadasSub = null;
    _bovinosSub?.cancel();
    _bovinosSub = null;
    _eventosSub?.cancel();
    _eventosSub = null;
    _atividadesSub?.cancel();
    _atividadesSub = null;
  }

  static Invernada _invernadaFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data()!;
    return Invernada(
      id: null,
      syncId: doc.id,
      descricao: d['descricao'] as String? ?? '',
      hectares: (d['hectares'] as num?)?.toDouble(),
      urlFoto: d['urlFoto'] as String?,
      observacoes: d['observacoes'] as String?,
    );
  }

  static Future<Bovino> _bovinoFromDoc(
    Database db,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final d = doc.data()!;
    final invernadaId = await SyncRefs.idRemotoResolvido(
      db,
      'invernadas',
      syncId: d['invernadaSyncId'] as String?,
      legacyId: _intOuNull(d['invernadaId']),
    );
    final idMae = await SyncRefs.idRemotoResolvido(
      db,
      'bovinos',
      syncId: d['maeSyncId'] as String?,
      legacyId: _intOuNull(d['idMae']),
    );
    return Bovino(
      id: null,
      syncId: doc.id,
      numeroBrinco: d['numeroBrinco'] as String? ?? '',
      nomeAnimal: d['nomeAnimal'] as String?,
      codigoEpc: d['codigoEpc'] as String?,
      codigoInterno: d['codigoInterno'] as String?,
      raca: d['raca'] as String?,
      dataNascimento: d['dataNascimento'] as String?,
      dataNascimentoMillis: _intOuNull(d['dataNascimentoMillis']),
      pesoAtualKg: _doubleOuNull(d['pesoAtualKg']),
      pelagem: d['pelagem'] as String?,
      sexo: d['sexo'] as String?,
      categoria: d['categoria'] as String?,
      status: d['status'] as String? ?? 'Ativo',
      origem: d['origem'] as String?,
      observacoes: d['observacoes'] as String?,
      foto: d['foto'] as String?,
      invernadaId: invernadaId,
      idMae: idMae,
      estaDeCria: (d['estaDeCria'] == true) ? 1 : 0,
    );
  }

  static Future<EventoSanitario> _eventoFromDoc(
    Database db,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final d = doc.data()!;
    final invernadaId = await SyncRefs.idRemotoResolvido(
      db,
      'invernadas',
      syncId: d['invernadaSyncId'] as String?,
      legacyId: _intOuNull(d['invernadaId']),
    );
    return EventoSanitario(
      id: null,
      syncId: doc.id,
      tipo: d['tipo'] as String? ?? 'Outros',
      dataEvento: d['dataEvento'] as String?,
      dataEventoMillis: _intOuNull(d['dataEventoMillis']),
      invernadaId: invernadaId,
      produtoUtilizado: d['produtoUtilizado'] as String?,
      dosagem: d['dosagem'] as String?,
      responsavel: d['responsavel'] as String?,
      observacoes: d['observacoes'] as String?,
    );
  }

  static int? _intOuNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return null;
  }

  static double? _doubleOuNull(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return null;
  }

  static List<int> _listaIntOuVazia(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map(_intOuNull).whereType<int>().toList();
    return [];
  }

  static List<String> _listaStringOuVazia(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.whereType<String>().toList();
    return [];
  }
}
