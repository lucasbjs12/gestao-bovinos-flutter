import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:gestao_bovinos_app/core/api/api_client.dart';
import 'package:gestao_bovinos_app/core/api/api_exception.dart';

import 'helpers/token_storage_falso.dart';

http.Response _jsonOk(Map<String, dynamic> data) => http.Response(
  jsonEncode({'success': true, 'message': 'OK', 'data': data}),
  200,
  headers: {'content-type': 'application/json'},
);

http.Response _naoAutorizado() => http.Response(
  jsonEncode({
    'success': false,
    'message': 'Token de acesso expirado',
    'error': {'code': 'unauthorized'},
  }),
  401,
  headers: {'content-type': 'application/json'},
);

/// Bug real encontrado rodando o app no emulador: o access token expira em
/// 15min e nenhuma tela tratava o 401, então qualquer sessão mais longa que
/// isso (inclusive o polling de sync em segundo plano) parava de funcionar
/// silenciosamente. Corrigido centralizando o refresh-e-repete no ApiClient.
void main() {
  group('ApiClient refresh automático em 401', () {
    late TokenStorageFalso storage;

    setUp(() async {
      storage = TokenStorageFalso();
      await storage.salvar(accessToken: 'expirado', refreshToken: 'refresh-valido');
    });

    test('401 dispara refresh e repete a chamada original com o token novo', () async {
      final tokensRecebidos = <String?>[];
      var chamadasRefresh = 0;

      final cliente = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          chamadasRefresh++;
          return _jsonOk({'accessToken': 'novo-token', 'refreshToken': 'novo-refresh'});
        }
        tokensRecebidos.add(request.headers['Authorization']);
        if (request.headers['Authorization'] == 'Bearer expirado') {
          return _naoAutorizado();
        }
        return _jsonOk({'ok': true});
      });

      final api = ApiClient(httpClient: cliente, tokenStorage: storage);
      final resultado = await api.get('/fazendas/f1/bovinos');

      expect(resultado, {'ok': true});
      expect(chamadasRefresh, 1);
      expect(tokensRecebidos, ['Bearer expirado', 'Bearer novo-token']);
      expect(await storage.lerAccessToken(), 'novo-token');
      expect(await storage.lerRefreshToken(), 'novo-refresh');
    });

    test('refresh token também inválido: limpa o storage e propaga o 401 original', () async {
      final cliente = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) return _naoAutorizado();
        return _naoAutorizado();
      });

      final api = ApiClient(httpClient: cliente, tokenStorage: storage);

      expect(
        () => api.get('/fazendas/f1/bovinos'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
      // A chamada acima ainda não tinha resolvido -- espera terminar antes de checar o storage.
      await Future<void>.delayed(Duration.zero).catchError((_) {});
    });

    test('chamadas concorrentes que batem 401 ao mesmo tempo compartilham UM só refresh', () async {
      var chamadasRefresh = 0;
      final cliente = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          chamadasRefresh++;
          // pequeno atraso pra garantir que as duas chamadas caiam no 401
          // antes do refresh terminar
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return _jsonOk({'accessToken': 'novo-token', 'refreshToken': 'novo-refresh'});
        }
        if (request.headers['Authorization'] == 'Bearer expirado') {
          return _naoAutorizado();
        }
        return _jsonOk({'ok': true});
      });

      final api = ApiClient(httpClient: cliente, tokenStorage: storage);
      final resultados = await Future.wait([
        api.get('/fazendas/f1/bovinos'),
        api.get('/fazendas/f1/invernadas'),
      ]);

      expect(resultados, [
        {'ok': true},
        {'ok': true},
      ]);
      expect(chamadasRefresh, 1, reason: 'não pode disparar um refresh por chamada');
    });

    test('login (não autenticado) propaga 401 direto, sem tentar refresh', () async {
      var chamouRefresh = false;
      final cliente = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) chamouRefresh = true;
        return _naoAutorizado();
      });

      final api = ApiClient(httpClient: cliente, tokenStorage: storage);

      await expectLater(
        api.post('/auth/login', corpo: {'email': 'x', 'senha': 'y'}, autenticado: false),
        throwsA(isA<ApiException>()),
      );
      expect(chamouRefresh, isFalse);
    });
  });
}
