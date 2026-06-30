import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';

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
            await repo.inserirOuSubstituirPorSyncId(_bovinoFromDoc(change.doc));
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
            final bovinoIds = _listaIntOuVazia(d['bovinoIds']);
            final evento = _eventoFromDoc(change.doc);
            await repo.inserirOuSubstituirPorSyncId(evento, bovinoIds);
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

  static Bovino _bovinoFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data()!;
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
      invernadaId: _intOuNull(d['invernadaId']),
      idMae: _intOuNull(d['idMae']),
      estaDeCria: (d['estaDeCria'] == true) ? 1 : 0,
    );
  }

  static EventoSanitario _eventoFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data()!;
    return EventoSanitario(
      id: null,
      syncId: doc.id,
      tipo: d['tipo'] as String? ?? 'Outros',
      dataEvento: d['dataEvento'] as String?,
      dataEventoMillis: _intOuNull(d['dataEventoMillis']),
      invernadaId: _intOuNull(d['invernadaId']),
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
}
