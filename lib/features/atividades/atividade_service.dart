import 'package:firebase_auth/firebase_auth.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_status_service.dart';
import 'data/atividade.dart';
import 'data/atividade_local_repository.dart';
import 'data/atividade_remote_repository.dart';

/// Grava uma entrada no diário de atividades (local + nuvem).
///
/// Chamado pelos repositórios remotos, que são o funil de toda mutação feita
/// pelo usuário — a sync que desce da nuvem não passa por eles, então não gera
/// eco no diário. Nunca lança: o diário jamais pode quebrar a operação
/// principal.
class AtividadeService {
  static Future<void> registrar({
    required String uid,
    required SyncStatusService sync,
    required String acao,
    required String descricao,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final nome = (user?.displayName?.isNotEmpty ?? false)
          ? user!.displayName
          : user?.email;

      final atividade = Atividade.criar(
        autorUid: uid,
        autorNome: nome,
        acao: acao,
        descricao: descricao,
      );

      final db = await AppDatabase.instance.instanceFor(uid);
      await AtividadeLocalRepository(db).inserir(atividade);
      AtividadeRemoteRepository(uid: uid, sync: sync).salvar(atividade);
    } catch (_) {}
  }
}
