import '../../core/sync/sync_status_service.dart';

/// O backend próprio já registra uma entrada no diário de atividades do
/// lado do servidor em cada escrita (bovino_salvo, evento_salvo, etc. --
/// ver `atividadeRepository.registrar` no backend), então não existe mais
/// endpoint para gravar uma atividade "à mão" pelo cliente. O diário local
/// é preenchido só de leitura pelo `PollingSyncService`.
///
/// Método mantido vazio (em vez de remover todos os call sites espalhados
/// pelo app) só para não quebrar quem ainda chama isso.
class AtividadeService {
  static Future<void> registrar({
    required String uid,
    required SyncStatusService sync,
    required String acao,
    required String descricao,
  }) async {}
}
