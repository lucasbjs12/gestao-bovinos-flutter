import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/db/app_database.dart';
import '../../../core/sync/outbox.dart';
import '../../../core/sync/sync_refs.dart';
import '../../../core/sync/sync_status_service.dart';
import '../../../core/utils/data_iso.dart';
import 'evento_sanitario.dart';
import 'tipo_evento_mapping.dart';

class EventoSanitarioRemoteRepository {
  final String uid;
  final SyncStatusService _sync;
  final ApiClient _api;

  // O campo é privado (_sync) mas o parâmetro precisa ficar público (sync)
  // pra quem chama de fora do arquivo, então não dá pra usar `this._sync`.
  EventoSanitarioRemoteRepository({
    required this.uid,
    required SyncStatusService sync,
    ApiClient? apiClient,
  }) : _sync = sync, // ignore: prefer_initializing_formals
       _api = apiClient ?? ApiClient();

  String get _base => '/fazendas/$uid/eventos-sanitarios';

  /// [registrarAtividade] não tem efeito no backend (todo write já loga no
  /// diário do lado do servidor) -- mantido só para não quebrar quem chama.
  Future<void> salvar(
    EventoSanitario evento,
    List<int> bovinoIds, {
    bool registrarAtividade = true,
  }) async {
    if (bovinoIds.isEmpty) return; // backend exige ao menos 1 animal
    final db = await AppDatabase.instance.instanceFor(uid);
    final bovinoSyncIds = await SyncRefs.syncIdsDeBovinos(db, bovinoIds);
    // Os ids locais existiam (checado acima), mas nenhum resolveu pra um
    // syncId válido (podem ter sido apagados nesse meio tempo) -- mandar
    // uma lista vazia pro backend é rejeitado (exige pelo menos 1 animal),
    // então nem tenta; melhor deixar como estava do que travar a fila com
    // um payload que nunca vai ser aceito.
    if (bovinoSyncIds.isEmpty) return;
    final invernadaSyncId = await SyncRefs.syncIdPorId(db, 'invernadas', evento.invernadaId);

    final corpo = {
      'tipo': tipoEventoLocalParaBackend[evento.tipo] ?? evento.tipo,
      'dataEvento': dataBrParaIso(evento.dataEvento),
      'invernadaId': invernadaSyncId,
      'produtoUtilizado': evento.produtoUtilizado,
      'dosagem': evento.dosagem,
      'responsavel': evento.responsavel,
      'observacoes': evento.observacoes,
      'bovinoIds': bovinoSyncIds,
    };

    try {
      try {
        await _api.put('$_base/${evento.syncId}', corpo: corpo);
      } on ApiException catch (e) {
        if (e.statusCode != 404) rethrow;
        await _api.post(_base, corpo: {...corpo, 'id': evento.syncId});
      }
      _sync.notificarEscrita();
    } catch (_) {
      final outbox = Outbox(db);
      await outbox.enfileirarUpsert(
        caminhoBase: _base,
        syncId: evento.syncId,
        corpo: corpo,
        descricao: 'Evento ${evento.tipo}',
      );
      await outbox.avisar(_sync);
    }
  }

  Future<void> excluir(String syncId) async {
    try {
      await _api.delete('$_base/$syncId');
      _sync.notificarEscrita();
    } catch (_) {
      final db = await AppDatabase.instance.instanceFor(uid);
      final outbox = Outbox(db);
      await outbox.enfileirarChamada(
        metodo: 'DELETE',
        caminho: '$_base/$syncId',
        descricao: 'Excluir evento sanitário',
      );
      await outbox.avisar(_sync);
    }
  }
}
