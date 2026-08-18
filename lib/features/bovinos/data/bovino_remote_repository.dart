import 'package:sqflite/sqflite.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/db/app_database.dart';
import '../../../core/sync/outbox.dart';
import '../../../core/sync/sync_refs.dart';
import '../../../core/sync/sync_status_service.dart';
import '../../../core/utils/data_iso.dart';
import 'bovino.dart';

/// Espelha cada operação no backend próprio (fire-and-forget -- quem chama
/// não espera nem trata o resultado). Se a chamada falhar (tipicamente por
/// falta de conexão), a operação vai pro [Outbox] em vez de se perder --
/// o [PollingSyncService] tenta reenviar a cada rodada e assim que a
/// conexão volta.
class BovinoRemoteRepository {
  final String uid;
  final SyncStatusService _sync;
  final ApiClient _api;

  // O campo é privado (_sync) mas o parâmetro precisa ficar público (sync)
  // pra quem chama de fora do arquivo, então não dá pra usar `this._sync`.
  BovinoRemoteRepository({
    required this.uid,
    required SyncStatusService sync,
    ApiClient? apiClient,
  }) : _sync = sync, // ignore: prefer_initializing_formals
       _api = apiClient ?? ApiClient();

  String get _base => '/fazendas/$uid/bovinos';

  /// [registrarAtividade] não tem efeito no backend (todo write já loga no
  /// diário do lado do servidor) -- mantido só para não quebrar quem chama.
  Future<void> salvar(Bovino b, {bool registrarAtividade = true}) async {
    final db = await AppDatabase.instance.instanceFor(uid);
    final invernadaSyncId =
        await SyncRefs.syncIdPorId(db, 'invernadas', b.invernadaId);
    final maeSyncId = await SyncRefs.syncIdPorId(db, 'bovinos', b.idMae);
    final fotoPublica = fotoPublicaOuNull(b.foto);
    final fotoEhArquivoLocal = b.foto != null && fotoPublica == null;

    final corpo = {
      'nomeAnimal': b.nomeAnimal,
      'codigoEpc': b.codigoEpc,
      'codigoInterno': b.codigoInterno,
      'numeroBrinco': b.numeroBrinco,
      'raca': b.raca,
      'dataNascimento': dataBrParaIso(b.dataNascimento),
      'pesoAtualKg': b.pesoAtualKg,
      'pelagem': b.pelagem,
      'categoria': b.categoria,
      'origem': b.origem,
      'observacoes': b.observacoes,
      if (!fotoEhArquivoLocal) 'foto': fotoPublica,
      'invernadaId': invernadaSyncId,
      'idMae': maeSyncId,
      'estaDeCria': b.estaDeCria == 1,
      'corDestaque': b.corDestaque?.name,
      'rotuloDestaque': b.rotuloDestaque,
    };

    try {
      await _tentarUpsert(b.syncId, corpo);
      _sync.notificarEscrita();
    } on ApiException catch (e) {
      // Rejeição de regra de negócio (ex: limite do plano, brinco
      // duplicado) -- reenviar nunca vai adiantar, então não entra na fila
      // de retry (senão fica pra sempre "pendente" e some do usuário só
      // quando o próximo ciclo de sync descobrir por diferença). Quem
      // chamou decide o que fazer (normalmente: desfazer o registro local
      // e avisar o produtor).
      if (e.ehPermanente) rethrow;
      await _enfileirarPendente(db, b.syncId, corpo);
    } catch (_) {
      // Sem conexão de verdade.
      await _enfileirarPendente(db, b.syncId, corpo);
    }
  }

  Future<void> _tentarUpsert(String syncId, Map<String, dynamic> corpo) async {
    try {
      await _api.put('$_base/$syncId', corpo: corpo);
    } on ApiException catch (e) {
      if (e.statusCode != 404) rethrow;
      await _api.post(_base, corpo: {...corpo, 'id': syncId});
    }
  }

  Future<void> _enfileirarPendente(
    Database db,
    String syncId,
    Map<String, dynamic> corpo,
  ) async {
    final outbox = Outbox(db);
    await outbox.enfileirarUpsert(
      caminhoBase: _base,
      syncId: syncId,
      corpo: corpo,
      descricao: 'Bovino ${corpo['numeroBrinco']}',
    );
    await outbox.avisar(_sync);
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
        descricao: 'Excluir bovino',
      );
      await outbox.avisar(_sync);
    }
  }

  Future<void> darBaixa(
    String syncId, {
    required String motivo,
    required String dataBaixa,
    String? observacoes,
  }) async {
    final corpo = {
      'motivo': motivo,
      'dataBaixa': dataBrParaIso(dataBaixa),
      'observacoes': observacoes,
    };
    try {
      await _api.patch('$_base/$syncId/baixa', corpo: corpo);
      _sync.notificarEscrita();
    } catch (_) {
      final db = await AppDatabase.instance.instanceFor(uid);
      final outbox = Outbox(db);
      await outbox.enfileirarChamada(
        metodo: 'PATCH',
        caminho: '$_base/$syncId/baixa',
        corpo: corpo,
        descricao: 'Baixa de bovino',
      );
      await outbox.avisar(_sync);
    }
  }

  Future<void> reativar(String syncId) async {
    try {
      await _api.patch('$_base/$syncId/reativar');
      _sync.notificarEscrita();
    } catch (_) {
      final db = await AppDatabase.instance.instanceFor(uid);
      final outbox = Outbox(db);
      await outbox.enfileirarChamada(
        metodo: 'PATCH',
        caminho: '$_base/$syncId/reativar',
        descricao: 'Reativar bovino',
      );
      await outbox.avisar(_sync);
    }
  }
}

String? fotoPublicaOuNull(String? foto) {
  if (foto == null) return null;
  final uri = Uri.tryParse(foto);
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return foto;
}
