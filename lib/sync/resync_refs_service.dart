import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../core/sync/sync_status_service.dart';
import '../features/bovinos/data/bovino.dart';
import '../features/bovinos/data/bovino_remote_repository.dart';
import '../features/eventos_sanitarios/data/evento_sanitario.dart';
import '../features/eventos_sanitarios/data/evento_sanitario_remote_repository.dart';

/// Regrava bovinos e eventos no Firestore uma única vez por aparelho para que
/// docs antigos ganhem as referências por syncId (invernadaSyncId, maeSyncId,
/// bovinoSyncIds). As escritas entram na fila offline do SDK, então funciona
/// mesmo sem sinal.
class ResyncRefsService {
  static const _prefsPrefix = 'resync_refs_v1_';

  static Future<void> executarUmaVez({
    required String uid,
    required Database db,
    required SyncStatusService sync,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('$_prefsPrefix$uid') ?? false) return;

    final bovinoRepo = BovinoRemoteRepository(uid: uid, sync: sync);
    for (final row in await db.query('bovinos')) {
      await bovinoRepo.salvar(Bovino.fromMap(row));
    }

    final eventoRepo = EventoSanitarioRemoteRepository(uid: uid, sync: sync);
    for (final row in await db.query('eventos_sanitarios')) {
      final syncId = row['syncId'] as String?;
      if (syncId == null || syncId.isEmpty) continue;
      final vinculos = await db.query(
        'evento_sanitario_bovino',
        columns: ['bovinoId'],
        where: 'eventoId = ?',
        whereArgs: [row['id']],
      );
      final evento = EventoSanitario(
        id: row['id'] as int?,
        syncId: syncId,
        tipo: row['tipo'] as String? ?? 'Outros',
        dataEvento: row['dataEvento'] as String?,
        dataEventoMillis: row['dataEventoMillis'] as int?,
        invernadaId: row['invernadaId'] as int?,
        produtoUtilizado: row['produtoUtilizado'] as String?,
        dosagem: row['dosagem'] as String?,
        responsavel: row['responsavel'] as String?,
        observacoes: row['observacoes'] as String?,
      );
      await eventoRepo.salvar(
        evento,
        vinculos.map((v) => v['bovinoId'] as int).toList(),
      );
    }

    await prefs.setBool('$_prefsPrefix$uid', true);
  }
}
