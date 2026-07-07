import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Baixa invernadas, bovinos e eventos do Firestore para o sqflite na primeira
/// vez que o usuário abre o app em um dispositivo.
/// Se estiver offline, falha silenciosamente e tenta de novo na próxima abertura.
class InitialSyncService {
  static const _prefsPrefix = 'sync_inicial_v3_';

  static Future<bool> jaSincronizou(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefsPrefix$uid') ?? false;
  }

  static Future<void> sincronizar({
    required String uid,
    required Database db,
  }) async {
    final fazendaRef =
        FirebaseFirestore.instance.collection('fazendas').doc(uid);

    // Busca paralela das 4 coleções
    final results = await Future.wait([
      fazendaRef.collection('invernadas').get(const GetOptions(source: Source.server)),
      fazendaRef.collection('bovinos').get(const GetOptions(source: Source.server)),
      fazendaRef.collection('eventos_sanitarios').get(const GetOptions(source: Source.server)),
      fazendaRef.collection('atividades').get(const GetOptions(source: Source.server)),
    ]);

    final invernadasSnap = results[0];
    final bovinosSnap    = results[1];
    final eventosSnap    = results[2];
    final atividadesSnap = results[3];

    // 1 — Invernadas (FK base para bovinos)
    final invRepo = InvernadaLocalRepository(db);
    for (final doc in invernadasSnap.docs) {
      if (doc.metadata.hasPendingWrites) continue;
      await invRepo.inserirOuSubstituirPorSyncId(_invernadaFromDoc(doc));
    }

    // 2 — Bovinos (2 passes para resolver idMae auto-referencial)
    final bovRepo = BovinoLocalRepository(db);
    final pendingMaeSyncId = <String, String>{};
    final pendingMaeLegacy = <String, int>{};

    for (final doc in bovinosSnap.docs) {
      if (doc.metadata.hasPendingWrites) continue;
      final d = doc.data();
      // invernadaSyncId (novo) tem prioridade sobre o id legado do aparelho
      // de origem; as invernadas já foram inseridas no passo 1.
      final invernadaId = await SyncRefs.idRemotoResolvido(
        db,
        'invernadas',
        syncId: d['invernadaSyncId'] as String?,
        legacyId: _intOuNull(d['invernadaId']),
      );
      final b = Bovino(
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
        idMae: null,
        estaDeCria: (d['estaDeCria'] == true) ? 1 : 0,
      );
      await bovRepo.inserirOuSubstituirPorSyncId(b);
      final maeSyncId = d['maeSyncId'] as String?;
      if (maeSyncId != null && maeSyncId.isNotEmpty) {
        pendingMaeSyncId[doc.id] = maeSyncId;
      } else {
        final idMae = _intOuNull(d['idMae']);
        if (idMae != null) pendingMaeLegacy[doc.id] = idMae;
      }
    }
    for (final entry in pendingMaeSyncId.entries) {
      final maeLocalId = await SyncRefs.idPorSyncId(db, 'bovinos', entry.value);
      if (maeLocalId != null) {
        await bovRepo.atualizarIdMaePorSyncId(entry.key, maeLocalId);
      }
    }
    for (final entry in pendingMaeLegacy.entries) {
      await bovRepo.atualizarIdMaePorSyncId(entry.key, entry.value);
    }

    // 3 — Eventos sanitários (depende de invernadas e bovinos)
    final evRepo = EventoSanitarioLocalRepository(db);
    for (final doc in eventosSnap.docs) {
      if (doc.metadata.hasPendingWrites) continue;
      final d = doc.data();
      // bovinoSyncIds (novo) resolve para os ids locais deste aparelho;
      // docs antigos caem no fallback por bovinoIds legados que existam.
      final bovinosLocais = await SyncRefs.idsDeBovinosRemotos(
        db,
        syncIds: _listaStringOuVazia(d['bovinoSyncIds']),
        legacyIds: _listaIntOuVazia(d['bovinoIds']),
      );
      final invernadaId = await SyncRefs.idRemotoResolvido(
        db,
        'invernadas',
        syncId: d['invernadaSyncId'] as String?,
        legacyId: _intOuNull(d['invernadaId']),
      );
      final evento = EventoSanitario(
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
      await evRepo.inserirOuSubstituirPorSyncId(evento, bovinosLocais);
    }

    // 4 — Diário de atividades
    final atRepo = AtividadeLocalRepository(db);
    for (final doc in atividadesSnap.docs) {
      if (doc.metadata.hasPendingWrites) continue;
      await atRepo.inserirOuSubstituirPorSyncId(
        Atividade.fromMap({...doc.data(), 'syncId': doc.id, 'id': null}),
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefsPrefix$uid', true);
  }

  static Invernada _invernadaFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    return Invernada(
      id: null,
      syncId: doc.id,
      descricao: d['descricao'] as String? ?? '',
      hectares: (d['hectares'] as num?)?.toDouble(),
      urlFoto: d['urlFoto'] as String?,
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
