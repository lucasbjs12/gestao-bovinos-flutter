import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:gestao_bovinos_app/core/api/api_client.dart';
import 'package:gestao_bovinos_app/core/sync/outbox.dart';

import 'helpers/db_helper.dart';
import 'helpers/token_storage_falso.dart';

http.Response _jsonOk({int status = 200}) => http.Response(
  jsonEncode({'success': true, 'message': 'OK', 'data': null}),
  status,
  headers: {'content-type': 'application/json'},
);

http.Response _jsonNaoEncontrado() => http.Response(
  jsonEncode({
    'success': false,
    'message': 'Bovino nao encontrado',
    'error': {'code': 'not_found'},
  }),
  404,
  headers: {'content-type': 'application/json'},
);

http.Response _jsonValidacao() => http.Response(
  jsonEncode({
    'success': false,
    'message': 'Selecione ao menos um animal',
    'error': {'code': 'validation_error'},
  }),
  422,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('Outbox', () {
    test('escrita que falha (offline) fica pendente e não se perde', () async {
      final db = await criarDbTeste();
      final falso = TokenStorageFalso();

      // Simula "sem rede": toda chamada estoura.
      final clienteOffline = MockClient((_) async => throw Exception('sem rede'));
      final outbox = Outbox(
        db,
        apiClient: ApiClient(httpClient: clienteOffline, tokenStorage: falso),
      );

      await outbox.enfileirarUpsert(
        caminhoBase: '/fazendas/f1/bovinos',
        syncId: 'sync-1',
        corpo: {'numeroBrinco': '001', 'categoria': 'Vaca'},
        descricao: 'Bovino 001',
      );

      expect(await outbox.contar(), 1);

      // Ainda offline: tentar esvaziar não remove nada.
      final enviadas = await outbox.tentarEsvaziar();
      expect(enviadas, 0);
      expect(await outbox.contar(), 1);
    });

    test('quando a conexão volta, a fila esvazia e some do banco', () async {
      final db = await criarDbTeste();
      final falso = TokenStorageFalso();

      final chamadas = <String>[];
      final clienteOnline = MockClient((request) async {
        chamadas.add('${request.method} ${request.url.path}');
        return _jsonOk();
      });
      final outbox = Outbox(
        db,
        apiClient: ApiClient(httpClient: clienteOnline, tokenStorage: falso),
      );

      await outbox.enfileirarUpsert(
        caminhoBase: '/fazendas/f1/bovinos',
        syncId: 'sync-1',
        corpo: {'numeroBrinco': '001'},
      );
      await outbox.enfileirarChamada(
        metodo: 'DELETE',
        caminho: '/fazendas/f1/invernadas/sync-2',
      );

      final enviadas = await outbox.tentarEsvaziar();

      expect(enviadas, 2);
      expect(await outbox.contar(), 0);
      expect(chamadas, [
        'PUT /api/v1/fazendas/f1/bovinos/sync-1',
        'DELETE /api/v1/fazendas/f1/invernadas/sync-2',
      ]);
      // ^ ApiClient prefixa com o baseUrl (http://localhost:3000/api/v1),
      // por isso o path completo aqui já vem com /api/v1.
    });

    test('upsert cai para POST quando o PUT dá 404 (registro nunca chegou a existir no servidor)', () async {
      final db = await criarDbTeste();
      final falso = TokenStorageFalso();

      final chamadas = <String>[];
      final cliente = MockClient((request) async {
        chamadas.add(request.method);
        if (request.method == 'PUT') return _jsonNaoEncontrado();
        return _jsonOk(status: 201);
      });
      final outbox = Outbox(db, apiClient: ApiClient(httpClient: cliente, tokenStorage: falso));

      await outbox.enfileirarUpsert(
        caminhoBase: '/fazendas/f1/bovinos',
        syncId: 'sync-novo',
        corpo: {'numeroBrinco': '002'},
      );

      final enviadas = await outbox.tentarEsvaziar();

      expect(enviadas, 1);
      expect(chamadas, ['PUT', 'POST']);
      expect(await outbox.contar(), 0);
    });

    test('para no primeiro erro para preservar a ordem -- não pula pendências', () async {
      final db = await criarDbTeste();
      final falso = TokenStorageFalso();

      var chamada = 0;
      final cliente = MockClient((request) async {
        chamada++;
        // A primeira falha (ainda sem rede de verdade); as seguintes, se
        // fossem tentadas, funcionariam -- mas não devem ser tentadas.
        if (chamada == 1) throw Exception('sem rede');
        return _jsonOk();
      });
      final outbox = Outbox(db, apiClient: ApiClient(httpClient: cliente, tokenStorage: falso));

      await outbox.enfileirarChamada(metodo: 'DELETE', caminho: '/x/1');
      await outbox.enfileirarChamada(metodo: 'DELETE', caminho: '/x/2');

      final enviadas = await outbox.tentarEsvaziar();

      expect(enviadas, 0);
      expect(await outbox.contar(), 2);
      expect(chamada, 1);
    });

    test(
      'erro permanente (422) descarta só aquele item, sem travar os de trás -- '
      'bug real: um evento com payload sempre inválido travava outras 14 pendências pra sempre',
      () async {
        final db = await criarDbTeste();
        final falso = TokenStorageFalso();

        final chamadas = <String>[];
        final cliente = MockClient((request) async {
          chamadas.add(request.url.path);
          if (request.url.path.contains('evento-zumbi')) return _jsonValidacao();
          return _jsonOk();
        });
        final outbox = Outbox(db, apiClient: ApiClient(httpClient: cliente, tokenStorage: falso));

        await outbox.enfileirarUpsert(
          caminhoBase: '/fazendas/f1/eventos-sanitarios',
          syncId: 'evento-zumbi',
          corpo: {'tipo': 'Vacinacao', 'bovinoIds': []},
        );
        await outbox.enfileirarChamada(metodo: 'DELETE', caminho: '/fazendas/f1/bovinos/atras-dele');

        final enviadas = await outbox.tentarEsvaziar();

        expect(
          enviadas,
          1,
          reason: 'o item de trás devia ter sido enviado, não ficar preso atrás do zumbi',
        );
        expect(
          await outbox.contar(),
          0,
          reason: 'o item com erro permanente deve ser descartado, não ficar tentando pra sempre',
        );
      },
    );
  });
}
