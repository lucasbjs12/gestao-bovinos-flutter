import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show Database;

import 'package:gestao_bovinos_app/core/api/api_client.dart';
import 'package:gestao_bovinos_app/core/sync/outbox.dart';
import 'package:gestao_bovinos_app/core/sync/sync_status_service.dart';
import 'package:gestao_bovinos_app/features/bovinos/data/bovino.dart';
import 'package:gestao_bovinos_app/features/bovinos/data/bovino_local_repository.dart';
import 'package:gestao_bovinos_app/sync/polling_sync_service.dart';

import 'helpers/db_helper.dart';
import 'helpers/token_storage_falso.dart';

http.Response _listaVazia() => http.Response(
  jsonEncode({
    'success': true,
    'message': 'OK',
    'data': {
      'itens': [],
      'paginacao': {'page': 1, 'pageSize': 100, 'total': 0, 'totalPaginas': 1},
    },
  }),
  200,
  headers: {'content-type': 'application/json'},
);

http.Response _listaComBovinoSemFoto() => http.Response(
  jsonEncode({
    'success': true,
    'message': 'OK',
    'data': {
      'itens': [
        {
          'id': 'bov-local',
          'numeroBrinco': 'F-LOCAL',
          'categoria': 'Vaca',
          'status': 'Ativo',
          'foto': null,
          'estaDeCria': false,
        },
      ],
      'paginacao': {'page': 1, 'pageSize': 100, 'total': 1, 'totalPaginas': 1},
    },
  }),
  200,
  headers: {'content-type': 'application/json'},
);

/// Reproduz o bug relatado: cadastrar um bovino, o envio pro servidor ainda
/// não ter terminado (ou ter falhado), e a rodada de sync que roda logo em
/// seguida apagar o registro local só porque ele "não existe no servidor"
/// ainda -- quando na real ele só está pendente de envio.
void main() {
  test(
    'bovino com escrita pendente na fila NÃO é apagado mesmo que o servidor ainda não o tenha',
    () async {
      final Database db = await criarDbTeste();
      final falso = TokenStorageFalso();

      // O servidor responde "não tenho nenhum bovino" em toda consulta --
      // simula exatamente o estado real: o POST desse bovino específico
      // ainda não chegou lá.
      final cliente = MockClient((request) async {
        if (request.method == 'GET') return _listaVazia();
        // Qualquer tentativa de reenviar a operação pendente também falha
        // (ainda sem conexão de verdade) -- assim ela continua na fila.
        throw Exception('sem rede');
      });
      final api = ApiClient(httpClient: cliente, tokenStorage: falso);

      // Bovino já existe localmente (o usuário cadastrou) e tem uma
      // escrita "salvar" pendente na fila, exatamente como o
      // BovinoRemoteRepository.salvar() deixaria depois de uma falha.
      final bovinoRepo = BovinoLocalRepository(db);
      await bovinoRepo.inserir(
        const Bovino(
          syncId: 'bov-pendente',
          numeroBrinco: 'F-001',
          categoria: 'Vaca',
        ),
      );
      await Outbox(db).enfileirarUpsert(
        caminhoBase: '/fazendas/f1/bovinos',
        syncId: 'bov-pendente',
        corpo: {'numeroBrinco': 'F-001', 'categoria': 'Vaca'},
      );

      final sync = SyncStatusService();
      final pollingSync = PollingSyncService(apiClient: api);

      await pollingSync.start(uid: 'f1', db: db, sync: sync);

      final aindaExiste = await bovinoRepo.buscarPorSyncId('bov-pendente');
      expect(
        aindaExiste,
        isNotNull,
        reason:
            'o bovino pendente de envio não pode sumir só porque o GET ainda não o retornou',
      );

      // A UI deve continuar mostrando que há algo pendente de enviar.
      expect(sync.pendencias, 1);
    },
  );

  test(
    'depois que o envio pendente é confirmado, o bovino aparece na lista normalmente',
    () async {
      final Database db = await criarDbTeste();
      final falso = TokenStorageFalso();

      final cliente = MockClient((request) async {
        if (request.method == 'PUT') {
          // agora a "conexão voltou": o reenvio da fila funciona
          return http.Response(
            jsonEncode({'success': true, 'message': 'OK', 'data': null}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return _listaVazia();
      });
      final api = ApiClient(httpClient: cliente, tokenStorage: falso);

      final bovinoRepo = BovinoLocalRepository(db);
      await bovinoRepo.inserir(
        const Bovino(syncId: 'bov-2', numeroBrinco: 'F-002', categoria: 'Vaca'),
      );
      await Outbox(db).enfileirarUpsert(
        caminhoBase: '/fazendas/f1/bovinos',
        syncId: 'bov-2',
        corpo: {'numeroBrinco': 'F-002', 'categoria': 'Vaca'},
      );

      final sync = SyncStatusService();
      final pollingSync = PollingSyncService(apiClient: api);
      await pollingSync.start(uid: 'f1', db: db, sync: sync);

      expect(await Outbox(db).contar(), 0);
      expect(sync.pendencias, 0);
    },
  );
  test(
    'pull com foto remota nula preserva foto local ainda pendente de upload',
    () async {
      final Database db = await criarDbTeste();
      final falso = TokenStorageFalso();

      final cliente = MockClient((request) async {
        if (request.method == 'GET' && request.url.path.endsWith('/bovinos')) {
          return _listaComBovinoSemFoto();
        }
        return _listaVazia();
      });
      final api = ApiClient(httpClient: cliente, tokenStorage: falso);

      final bovinoRepo = BovinoLocalRepository(db);
      await bovinoRepo.inserir(
        const Bovino(
          syncId: 'bov-local',
          numeroBrinco: 'F-LOCAL',
          categoria: 'Vaca',
          foto: '/data/user/0/app/files/foto-local.jpg',
        ),
      );

      final pollingSync = PollingSyncService(apiClient: api);
      await pollingSync.start(uid: 'f1', db: db, sync: SyncStatusService());

      final atualizado = await bovinoRepo.buscarPorSyncId('bov-local');
      expect(atualizado!.foto, '/data/user/0/app/files/foto-local.jpg');
    },
  );
}
