import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/db/app_database.dart';
import '../../../core/sync/outbox.dart';
import '../../../core/sync/sync_refs.dart';
import '../../../core/sync/sync_status_service.dart';
import '../../../core/utils/data_iso.dart';
import '../../bovinos/data/bovino.dart';
import '../../bovinos/data/bovino_remote_repository.dart';
import 'invernada.dart';
import 'movimentacao_invernada.dart';

class InvernadaRemoteRepository {
  final String uid;
  final SyncStatusService _sync;
  final ApiClient _api;

  // O campo é privado (_sync) mas o parâmetro precisa ficar público (sync)
  // pra quem chama de fora do arquivo, então não dá pra usar `this._sync`.
  InvernadaRemoteRepository({
    required this.uid,
    required SyncStatusService sync,
    ApiClient? apiClient,
  }) : _sync = sync, // ignore: prefer_initializing_formals
       _api = apiClient ?? ApiClient();

  String get _base => '/fazendas/$uid/invernadas';

  Future<void> salvar(Invernada i) async {
    final corpo = {
      'descricao': i.descricao,
      'hectares': i.hectares,
      'urlFoto': i.urlFoto,
      'observacoes': i.observacoes,
    };
    try {
      try {
        await _api.put('$_base/${i.syncId}', corpo: corpo);
      } on ApiException catch (e) {
        if (e.statusCode != 404) rethrow;
        await _api.post(_base, corpo: {...corpo, 'id': i.syncId});
      }
      _sync.notificarEscrita();
    } catch (_) {
      final db = await AppDatabase.instance.instanceFor(uid);
      final outbox = Outbox(db);
      await outbox.enfileirarUpsert(
        caminhoBase: _base,
        syncId: i.syncId,
        corpo: corpo,
        descricao: 'Invernada ${i.descricao}',
      );
      await outbox.avisar(_sync);
    }
  }

  /// Exclui a invernada e re-salva os bovinos afetados com invernadaId = null.
  Future<void> excluirComBovinos(String syncId, List<Bovino> bovinosAfetados) async {
    try {
      await _api.delete('$_base/$syncId');
      final bovinoRepo = BovinoRemoteRepository(uid: uid, sync: _sync);
      for (final b in bovinosAfetados) {
        await bovinoRepo.salvar(b, registrarAtividade: false);
      }
      _sync.notificarEscrita();
    } catch (_) {
      final db = await AppDatabase.instance.instanceFor(uid);
      final outbox = Outbox(db);
      await outbox.enfileirarChamada(
        metodo: 'DELETE',
        caminho: '$_base/$syncId',
        descricao: 'Excluir invernada',
      );
      await outbox.avisar(_sync);
      // Os bovinos afetados já foram atualizados localmente; a próxima
      // rodada de sync/edição individual reenvia cada um deles.
    }
  }

  /// Registra a movimentação no backend (que já atualiza o invernadaId do
  /// bovino do lado do servidor -- diferente do Firestore, aqui não precisa
  /// salvar o bovino de novo separadamente).
  Future<void> salvarMovimentacao(MovimentacaoInvernada m, int localId) async {
    if (m.novaInvernadaId == null) return; // backend exige destino não-nulo
    final db = await AppDatabase.instance.instanceFor(uid);
    final bovinoSyncId = await SyncRefs.syncIdPorId(db, 'bovinos', m.bovinoId);
    final novaSyncId = await SyncRefs.syncIdPorId(db, 'invernadas', m.novaInvernadaId);
    if (bovinoSyncId == null || novaSyncId == null) return;

    final corpo = {
      'bovinoId': bovinoSyncId,
      'novaInvernadaId': novaSyncId,
      'data': dataBrParaIso(m.data),
      'responsavel': m.responsavel,
      'observacoes': m.observacoes,
    };
    try {
      await _api.post('/fazendas/$uid/movimentacoes', corpo: corpo);
      _sync.notificarEscrita();
    } catch (_) {
      final outbox = Outbox(db);
      await outbox.enfileirarChamada(
        metodo: 'POST',
        caminho: '/fazendas/$uid/movimentacoes',
        corpo: corpo,
        descricao: 'Movimentação de bovino',
      );
      await outbox.avisar(_sync);
    }
  }
}
