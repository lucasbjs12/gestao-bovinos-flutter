import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/cloudinary_service.dart';
import '../../../core/sync/outbox.dart';
import 'bovino_local_repository.dart';

typedef BovinoFotoUploader =
    Future<String> Function(
      File file, {
      required String fazendaId,
      ApiClient? apiClient,
    });

class BovinoPhotoSyncService {
  BovinoPhotoSyncService({
    required this.uid,
    required Database db,
    ApiClient? apiClient,
    BovinoFotoUploader? uploader,
  }) : _db = db,
       _api = apiClient ?? ApiClient(),
       _uploader = uploader ?? CloudinaryService.upload;

  final String uid;
  final Database _db;
  final ApiClient _api;
  final BovinoFotoUploader _uploader;

  Future<int> reenviarPendentes({int limite = 20}) async {
    final repo = BovinoLocalRepository(_db);
    final pendentes = await repo.listarComFotoLocal(limit: limite);
    var enviadas = 0;

    for (final bovino in pendentes) {
      final caminho = bovino.foto;
      if (caminho == null) continue;

      final arquivo = File(caminho);
      if (!await arquivo.exists()) continue;

      try {
        final url = await _uploader(arquivo, fazendaId: uid, apiClient: _api);
        await repo.atualizarFotoPorSyncId(bovino.syncId, url);
        try {
          await _api.put(
            '/fazendas/$uid/bovinos/${bovino.syncId}',
            corpo: {'foto': url},
          );
        } catch (_) {
          await Outbox(_db, apiClient: _api).enfileirarChamada(
            metodo: 'PUT',
            caminho: '/fazendas/$uid/bovinos/${bovino.syncId}',
            corpo: {'foto': url},
            syncId: bovino.syncId,
            descricao: 'Foto do bovino ${bovino.numeroBrinco}',
          );
          break;
        }
        enviadas++;
      } catch (_) {
        break;
      }
    }

    return enviadas;
  }
}
