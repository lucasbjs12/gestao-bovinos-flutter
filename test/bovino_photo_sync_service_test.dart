import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:gestao_bovinos_app/core/api/api_client.dart';
import 'package:gestao_bovinos_app/core/sync/outbox.dart';
import 'package:gestao_bovinos_app/features/bovinos/data/bovino.dart';
import 'package:gestao_bovinos_app/features/bovinos/data/bovino_local_repository.dart';
import 'package:gestao_bovinos_app/features/bovinos/data/bovino_photo_sync_service.dart';

import 'helpers/db_helper.dart';
import 'helpers/token_storage_falso.dart';

void main() {
  test(
    'reenviarPendentes sobe foto local e atualiza a API com URL publica',
    () async {
      final db = await criarDbTeste();
      final arquivo = File(
        '${Directory.systemTemp.path}/bovino-foto-sync-ok.jpg',
      );
      await arquivo.writeAsBytes([1, 2, 3]);
      addTearDown(() async {
        if (await arquivo.exists()) await arquivo.delete();
      });

      final repo = BovinoLocalRepository(db);
      await repo.inserir(
        Bovino(
          syncId: 'bov-foto-1',
          numeroBrinco: '101',
          categoria: 'Vaca',
          foto: arquivo.path,
        ),
      );

      Map<String, dynamic>? corpoRecebido;
      final api = ApiClient(
        tokenStorage: TokenStorageFalso(),
        httpClient: MockClient((request) async {
          corpoRecebido = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'success': true, 'message': 'OK', 'data': {}}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final service = BovinoPhotoSyncService(
        uid: 'f1',
        db: db,
        apiClient: api,
        uploader: (_, {required fazendaId, apiClient}) async =>
            'https://res.cloudinary.com/demo/image/upload/bovino.jpg',
      );

      expect(await service.reenviarPendentes(), 1);

      final atualizado = await repo.buscarPorSyncId('bov-foto-1');
      expect(
        atualizado!.foto,
        'https://res.cloudinary.com/demo/image/upload/bovino.jpg',
      );
      expect(corpoRecebido, {
        'foto': 'https://res.cloudinary.com/demo/image/upload/bovino.jpg',
      });
      expect(await Outbox(db).contar(), 0);
    },
  );

  test(
    'se API falha depois do upload, URL fica local e atualizacao entra na fila',
    () async {
      final db = await criarDbTeste();
      final arquivo = File(
        '${Directory.systemTemp.path}/bovino-foto-sync-fila.jpg',
      );
      await arquivo.writeAsBytes([1, 2, 3]);
      addTearDown(() async {
        if (await arquivo.exists()) await arquivo.delete();
      });

      final repo = BovinoLocalRepository(db);
      await repo.inserir(
        Bovino(
          syncId: 'bov-foto-2',
          numeroBrinco: '102',
          categoria: 'Vaca',
          foto: arquivo.path,
        ),
      );

      final api = ApiClient(
        tokenStorage: TokenStorageFalso(),
        httpClient: MockClient((_) async => throw Exception('sem rede')),
      );

      final service = BovinoPhotoSyncService(
        uid: 'f1',
        db: db,
        apiClient: api,
        uploader: (_, {required fazendaId, apiClient}) async =>
            'https://res.cloudinary.com/demo/image/upload/bovino-2.jpg',
      );

      expect(await service.reenviarPendentes(), 0);

      final atualizado = await repo.buscarPorSyncId('bov-foto-2');
      expect(
        atualizado!.foto,
        'https://res.cloudinary.com/demo/image/upload/bovino-2.jpg',
      );
      expect(await Outbox(db).contar(), 1);
      expect(await Outbox(db).syncIdsComEscritaPendente(), {'bov-foto-2'});
    },
  );
}
