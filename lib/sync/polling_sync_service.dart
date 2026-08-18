import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../core/api/api_client.dart';
import '../core/api/paginacao.dart';
import '../core/sync/outbox.dart';
import '../core/sync/sync_refs.dart';
import '../core/sync/sync_status_service.dart';
import '../features/atividades/data/atividade.dart';
import '../features/atividades/data/atividade_local_repository.dart';
import '../features/bovinos/data/bovino.dart';
import '../features/bovinos/data/bovino_local_repository.dart';
import '../features/bovinos/data/bovino_photo_sync_service.dart';
import '../features/bovinos/data/bovino_remote_repository.dart';
import '../features/eventos_sanitarios/data/evento_sanitario.dart';
import '../features/eventos_sanitarios/data/evento_sanitario_local_repository.dart';
import '../features/eventos_sanitarios/data/tipo_evento_mapping.dart';
import '../features/invernadas/data/invernada.dart';
import '../features/invernadas/data/invernada_local_repository.dart';

/// Substitui o `RealtimeSyncService` (que escutava `.snapshots()` do
/// Firestore) por polling: o backend REST não tem push -- busca tudo de
/// novo periodicamente e aplica a diferença no sqflite local (upsert +
/// exclui o que sumiu do servidor).
class PollingSyncService {
  PollingSyncService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Timer? _timer;
  bool _rodando = false;
  String? _fazendaId;
  Database? _db;
  SyncStatusService? _sync;

  static const _intervalo = Duration(seconds: 45);

  /// Espera a primeira rodada terminar antes de retornar (substitui o que
  /// era o `InitialSyncService` -- a primeira rodada de polling É a sync
  /// inicial, não precisa de um serviço separado nem de flag "já sincronizou").
  Future<void> start({
    required String uid,
    required Database db,
    required SyncStatusService sync,
  }) async {
    if (_timer != null) return; // idempotente
    _fazendaId = uid;
    _db = db;
    _sync = sync;
    await sincronizarAgora();
    _timer = Timer.periodic(_intervalo, (_) => sincronizarAgora());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _fazendaId = null;
    _db = null;
    _sync = null;
  }

  /// Roda uma rodada de sync fora do timer (ex.: pull-to-refresh de uma
  /// tela, ou quando a conectividade volta). Não faz nada se já houver uma
  /// rodada em andamento.
  Future<void> sincronizarAgora() async {
    final uid = _fazendaId;
    final db = _db;
    final sync = _sync;
    if (uid == null || db == null || sync == null || _rodando) return;
    _rodando = true;
    try {
      // Esvazia primeiro o que ficou pendente de quando a conexão faltou --
      // as mudanças locais precisam chegar no servidor antes do pull abaixo,
      // senão a leitura logo em seguida traria o estado antigo de volta.
      final outbox = Outbox(db, apiClient: _api);
      await outbox.tentarEsvaziar();
      await outbox.avisar(sync);

      await BovinoPhotoSyncService(
        uid: uid,
        db: db,
        apiClient: _api,
      ).reenviarPendentes();
      await outbox.avisar(sync);

      // O que ainda ficou na fila (offline de verdade, ou envio que ainda
      // não terminou) não pode ser apagado localmente só por não aparecer
      // na resposta do servidor -- senão um cadastro recém-feito "some"
      // sozinho assim que o próximo ciclo de sync bate.
      final pendentes = await outbox.syncIdsComEscritaPendente();

      await _sincronizarInvernadas(uid, db, pendentes);
      await _sincronizarBovinos(uid, db, pendentes);
      await _sincronizarEventos(uid, db, pendentes);
      await _sincronizarAtividades(uid, db);
    } catch (_) {
      // offline ou erro passageiro -- tenta de novo no próximo ciclo
    } finally {
      _rodando = false;
    }
  }

  Future<void> _sincronizarInvernadas(
    String uid,
    Database db,
    Set<String> pendentes,
  ) async {
    final api = _api;
    final itens = await buscarTodasPaginas(api, '/fazendas/$uid/invernadas');
    final repo = InvernadaLocalRepository(db);

    final remotoIds = <String>{};
    for (final d in itens) {
      final syncId = d['id'] as String;
      remotoIds.add(syncId);
      await repo.inserirOuSubstituirPorSyncId(
        Invernada(
          syncId: syncId,
          descricao: d['descricao'] as String? ?? '',
          hectares: _doubleOuNull(d['hectares']),
          urlFoto: d['urlFoto'] as String?,
          observacoes: d['observacoes'] as String?,
        ),
      );
    }
    final locais = await repo.listarTodosSyncIds();
    for (final syncId in locais.difference(remotoIds).difference(pendentes)) {
      await repo.excluirPorSyncId(syncId);
    }
  }

  Future<void> _sincronizarBovinos(
    String uid,
    Database db,
    Set<String> pendentes,
  ) async {
    final api = _api;
    final itens = await buscarTodasPaginas(api, '/fazendas/$uid/bovinos');
    final repo = BovinoLocalRepository(db);

    final remotoIds = <String>{};

    // Pré-carrega em lote (uma query cada) o que antes era resolvido por
    // item dentro do loop: bovinos já existentes localmente (pra decidir
    // update vs insert e preservar a foto local) e o id local das
    // invernadas referenciadas. Evita 2 queries por bovino a cada rodada
    // de sync (que rodava a cada 45s pra todo o rebanho).
    final existentesPorSyncId = await repo.mapaPorSyncId(
      itens.map((d) => d['id'] as String),
    );
    final invernadaSyncIds = itens
        .map((d) => d['invernadaId'] as String?)
        .whereType<String>();
    final invernadaIdsPorSyncId = await SyncRefs.idsPorSyncIds(
      db,
      'invernadas',
      invernadaSyncIds,
    );

    // 1ª passada: upsert de tudo, sem idMae (pode referenciar um bovino
    // ainda não inserido nesta mesma rodada).
    for (final d in itens) {
      final syncId = d['id'] as String;
      remotoIds.add(syncId);
      final existente = existentesPorSyncId[syncId];
      final fotoRemota = d['foto'] as String?;
      final fotoLocalExistente = existente?.foto;
      final foto =
          fotoRemota ??
          (pendentes.contains(syncId) ||
                  fotoPublicaOuNull(fotoLocalExistente) == null
              ? fotoLocalExistente
              : null);
      final invernadaId = invernadaIdsPorSyncId[d['invernadaId'] as String?];
      final dataNascimentoStr = (d['dataNascimento'] as String?)?.substring(
        0,
        10,
      );
      await repo.inserirOuSubstituirPorSyncId(
        Bovino(
          syncId: syncId,
          numeroBrinco: d['numeroBrinco'] as String? ?? '',
          nomeAnimal: d['nomeAnimal'] as String?,
          codigoEpc: d['codigoEpc'] as String?,
          codigoInterno: d['codigoInterno'] as String?,
          raca: d['raca'] as String?,
          dataNascimento: dataNascimentoStr,
          // Campo só local (backend só guarda a data em si) -- recalcula
          // aqui, senão fica null a cada sync (mesma classe de bug do
          // dataEventoMillis dos eventos sanitários).
          dataNascimentoMillis: dataNascimentoStr != null
              ? DateTime.tryParse(dataNascimentoStr)?.millisecondsSinceEpoch
              : null,
          pesoAtualKg: _doubleOuNull(d['pesoAtualKg']),
          pelagem: d['pelagem'] as String?,
          categoria: d['categoria'] as String?,
          status: d['status'] as String? ?? 'Ativo',
          origem: d['origem'] as String?,
          observacoes: d['observacoes'] as String?,
          foto: foto,
          invernadaId: invernadaId,
          estaDeCria: (d['estaDeCria'] == true) ? 1 : 0,
          corDestaque: CorDestaque.fromNome(d['corDestaque'] as String?),
          rotuloDestaque: d['rotuloDestaque'] as String?,
          // `sexo` não existe no backend -- é campo só local, sempre derivado
          // da categoria (mesma regra do formulário de cadastro), pra não
          // zerar o valor a cada rodada de sync.
          sexo: _sexoDaCategoria(d['categoria'] as String?),
        ),
        idConhecido: existente?.id,
      );
    }
    // 2ª passada: resolve idMae agora que todo mundo já existe localmente.
    final maeSyncIds = itens
        .map((d) => d['idMae'] as String?)
        .whereType<String>();
    final maeIdsPorSyncId = await SyncRefs.idsPorSyncIds(
      db,
      'bovinos',
      maeSyncIds,
    );
    for (final d in itens) {
      final maeSyncId = d['idMae'] as String?;
      if (maeSyncId == null) continue;
      final maeId = maeIdsPorSyncId[maeSyncId];
      if (maeId != null) {
        await repo.atualizarIdMaePorSyncId(d['id'] as String, maeId);
      }
    }
    final locais = await repo.listarTodosSyncIds();
    for (final syncId in locais.difference(remotoIds).difference(pendentes)) {
      await repo.excluirPorSyncId(syncId);
    }
  }

  Future<void> _sincronizarEventos(
    String uid,
    Database db,
    Set<String> pendentes,
  ) async {
    final api = _api;
    final itens = await buscarTodasPaginas(
      api,
      '/fazendas/$uid/eventos-sanitarios',
    );
    final repo = EventoSanitarioLocalRepository(db);

    final remotoIds = <String>{};

    // Pré-carrega em lote os ids locais de invernadas e bovinos referenciados
    // por todos os eventos da página, em vez de uma query por evento (e por
    // bovino dentro de cada evento).
    final invernadaIdsPorSyncId = await SyncRefs.idsPorSyncIds(
      db,
      'invernadas',
      itens.map((d) => d['invernadaId'] as String?).whereType<String>(),
    );
    final todosBovinoSyncIds = itens
        .expand(
          (d) => (d['bovinos'] as List? ?? [])
              .map((b) => (b as Map<String, dynamic>)['bovinoId'] as String),
        )
        .toSet();
    final bovinoIdsPorSyncId = await SyncRefs.idsPorSyncIds(
      db,
      'bovinos',
      todosBovinoSyncIds,
    );

    for (final d in itens) {
      final syncId = d['id'] as String;
      remotoIds.add(syncId);
      final invernadaId = invernadaIdsPorSyncId[d['invernadaId'] as String?];
      final bovinosRemotos = (d['bovinos'] as List? ?? [])
          .map((b) => (b as Map<String, dynamic>)['bovinoId'] as String)
          .toList();
      final bovinoIds = [
        for (final bSyncId in bovinosRemotos)
          if (bovinoIdsPorSyncId[bSyncId] != null) bovinoIdsPorSyncId[bSyncId]!,
      ];
      final tipoBackend = d['tipo'] as String? ?? 'Outros';
      final dataEventoStr = (d['dataEvento'] as String?)?.substring(0, 10);
      // dataEventoMillis é um campo só local (o backend só guarda a data em
      // si) -- precisa ser recalculado aqui, senão fica null a cada sync e
      // o bovino "perde" o manejo nas telas que ordenam/filtram por isso
      // (ex. "Sem manejo").
      final dataEventoMillis = dataEventoStr != null
          ? DateTime.tryParse(dataEventoStr)?.millisecondsSinceEpoch
          : null;
      await repo.inserirOuSubstituirPorSyncId(
        EventoSanitario(
          syncId: syncId,
          tipo: tipoEventoBackendParaLocal[tipoBackend] ?? tipoBackend,
          dataEvento: dataEventoStr,
          dataEventoMillis: dataEventoMillis,
          invernadaId: invernadaId,
          produtoUtilizado: d['produtoUtilizado'] as String?,
          dosagem: d['dosagem'] as String?,
          responsavel: d['responsavel'] as String?,
          observacoes: d['observacoes'] as String?,
        ),
        bovinoIds,
      );
    }
    final locais = await repo.listarTodosSyncIds();
    for (final syncId in locais.difference(remotoIds).difference(pendentes)) {
      await repo.excluirPorSyncId(syncId);
    }
  }

  Future<void> _sincronizarAtividades(String uid, Database db) async {
    final api = _api;
    // Só as mais recentes -- é só um log de leitura, não precisa da
    // história inteira toda rodada (limita a 200 mais recentes).
    final resposta =
        await api.get('/fazendas/$uid/atividades?page=1&pageSize=100')
            as Map<String, dynamic>;
    final itens = (resposta['itens'] as List).cast<Map<String, dynamic>>();
    final repo = AtividadeLocalRepository(db);

    for (final d in itens) {
      final criadoEm = DateTime.tryParse(d['criadoEm'] as String? ?? '');
      await repo.inserirOuSubstituirPorSyncId(
        Atividade(
          syncId: d['id'] as String,
          autorUid: d['autorId'] as String? ?? uid,
          autorNome: d['autorNome'] as String?,
          acao: d['acao'] as String? ?? '',
          descricao: d['descricao'] as String? ?? '',
          dataMillis:
              criadoEm?.millisecondsSinceEpoch ??
              DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
  }

  static const _categoriasFemea = ['Vaca', 'Novilha', 'Terneira'];

  static String _sexoDaCategoria(String? categoria) =>
      _categoriasFemea.contains(categoria) ? 'Fêmea' : 'Macho';

  static double? _doubleOuNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
