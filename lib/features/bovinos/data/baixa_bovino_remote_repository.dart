import '../../../core/sync/sync_status_service.dart';
import 'baixa_bovino.dart';
import 'bovino.dart';
import 'bovino_remote_repository.dart';

/// Fina camada sobre [BovinoRemoteRepository] -- baixa/reativação/exclusão
/// permanente de um bovino baixado já são ações do próprio recurso Bovino
/// no backend (não existe mais uma coleção separada de "baixas").
class BaixaBovinoRemoteRepository {
  final String uid;
  final BovinoRemoteRepository _bovinoRepo;

  BaixaBovinoRemoteRepository({required this.uid, required SyncStatusService sync})
    : _bovinoRepo = BovinoRemoteRepository(uid: uid, sync: sync);

  Future<void> darBaixa(Bovino bovino, BaixaBovino baixa) => _bovinoRepo.darBaixa(
    bovino.syncId,
    motivo: baixa.motivo,
    dataBaixa: baixa.dataBaixa,
    observacoes: baixa.observacoes,
  );

  Future<void> reativar(Bovino bovino) => _bovinoRepo.reativar(bovino.syncId);

  Future<void> excluirPermanente({required String syncId, required int bovinoId}) =>
      _bovinoRepo.excluir(syncId);
}
