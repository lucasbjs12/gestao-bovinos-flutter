import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
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
    required this.db,
    ApiClient? apiClient,
    BovinoFotoUploader? uploader,
  }) : _api = apiClient ?? ApiClient(),
       _uploader = uploader ?? CloudinaryService.upload;

  final String uid;
  final Database db;
  final ApiClient _api;
  final BovinoFotoUploader _uploader;

  Future<int> reenviarPendentes({int limite = 20}) async {
    final repo = BovinoLocalRepository(db);
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
          enviadas++;
        } catch (e, st) {
          // PUT falhou (offline, 5xx) -- a foto já subiu pro Cloudinary e já
          // foi salva local, então enfileira só o PUT no outbox. Uma falha
          // de rede aqui não impede o upload das próximas fotos pendentes
          // nesta mesma rodada.
          _logNaoFatal(e, st, 'PUT de foto falhou, enfileirada no outbox');
          await Outbox(db, apiClient: _api).enfileirarChamada(
            metodo: 'PUT',
            caminho: '/fazendas/$uid/bovinos/${bovino.syncId}',
            corpo: {'foto': url},
            syncId: bovino.syncId,
            descricao: 'Foto do bovino ${bovino.numeroBrinco}',
          );
        }
      } catch (e, st) {
        // Upload em si falhou (Cloudinary indisponível, arquivo corrompido,
        // etc). Não interrompe as próximas fotos da rodada -- um arquivo
        // problemático não deve travar o restante da fila.
        _logNaoFatal(e, st, 'Upload de foto de bovino falhou');
      }
    }

    return enviadas;
  }

  // Crashlytics não roda na web -- fora dela, registra como não-fatal pra
  // dar visibilidade em produção sem interromper o fluxo de sync. O logging
  // em si nunca pode derrubar o sync (ex.: Firebase ainda não inicializado
  // em testes) -- por isso o try/catch silencioso aqui.
  void _logNaoFatal(Object e, StackTrace st, String razao) {
    if (kIsWeb) return;
    try {
      FirebaseCrashlytics.instance.recordError(e, st, reason: razao, fatal: false);
    } catch (_) {}
  }
}
