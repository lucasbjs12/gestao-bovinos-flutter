import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:gestao_bovinos_app/core/api/api_client.dart';
import 'package:gestao_bovinos_app/core/api/api_exception.dart';
import 'package:gestao_bovinos_app/features/auth/data/backend_auth_service.dart';

import 'helpers/token_storage_falso.dart';

http.Response _jsonOk(Map<String, dynamic> data, {String message = 'OK', int status = 200}) {
  return http.Response(
    jsonEncode({'success': true, 'message': message, 'data': data}),
    status,
    headers: {'content-type': 'application/json'},
  );
}

http.Response _jsonErro(String message, {int status = 400, String? codigo}) {
  return http.Response(
    jsonEncode({
      'success': false,
      'message': message,
      'error': codigo == null ? null : {'code': codigo},
    }),
    status,
    headers: {'content-type': 'application/json'},
  );
}

Map<String, dynamic> _usuarioMap() => {
  'id': 'u1',
  'nome': 'Teste',
  'email': 'teste@example.com',
  'isAdmin': false,
  'statusAssinatura': 'ativo',
};

void main() {
  group('BackendAuthService', () {
    late TokenStorageFalso storage;

    setUp(() {
      storage = TokenStorageFalso();
    });

    test('login guarda accessToken e refreshToken no storage', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/login');
        expect(request.method, 'POST');
        final corpo = jsonDecode(request.body) as Map<String, dynamic>;
        expect(corpo['email'], 'teste@example.com');
        return _jsonOk({
          'usuario': _usuarioMap(),
          'accessToken': 'access-123',
          'refreshToken': 'refresh-456',
        });
      });

      final service = BackendAuthService(
        apiClient: ApiClient(httpClient: client, tokenStorage: storage),
        tokenStorage: storage,
      );

      final sessao = await service.login(email: 'teste@example.com', senha: 'senha123');

      expect(sessao.usuario.email, 'teste@example.com');
      expect(sessao.accessToken, 'access-123');
      expect(await storage.lerAccessToken(), 'access-123');
      expect(await storage.lerRefreshToken(), 'refresh-456');
    });

    test('login com senha errada lanca ApiException com o status certo', () async {
      final client = MockClient((request) async => _jsonErro('E-mail ou senha invalidos', status: 401));

      final service = BackendAuthService(
        apiClient: ApiClient(httpClient: client, tokenStorage: storage),
        tokenStorage: storage,
      );

      expect(
        () => service.login(email: 'teste@example.com', senha: 'errada'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('requisicao autenticada manda o Authorization: Bearer com o token salvo', () async {
      await storage.salvar(accessToken: 'token-salvo', refreshToken: 'refresh-salvo');

      String? headerRecebido;
      final client = MockClient((request) async {
        headerRecebido = request.headers['Authorization'];
        return _jsonOk({
          'usuario': _usuarioMap(),
          'fazendaPropria': {'id': 'f1', 'donoId': 'u1', 'nome': 'Fazenda X'},
        });
      });

      final service = BackendAuthService(
        apiClient: ApiClient(httpClient: client, tokenStorage: storage),
        tokenStorage: storage,
      );

      final perfil = await service.me();

      expect(headerRecebido, 'Bearer token-salvo');
      expect(perfil.fazendaPropria?.nome, 'Fazenda X');
    });

    test('refresh sem token salvo retorna null sem chamar a API', () async {
      var chamou = false;
      final client = MockClient((request) async {
        chamou = true;
        return _jsonOk({});
      });

      final service = BackendAuthService(
        apiClient: ApiClient(httpClient: client, tokenStorage: storage),
        tokenStorage: storage,
      );

      final resultado = await service.refresh();

      expect(resultado, isNull);
      expect(chamou, isFalse);
    });

    test('refresh troca o par de tokens salvos', () async {
      await storage.salvar(accessToken: 'antigo', refreshToken: 'refresh-antigo');

      final client = MockClient((request) async {
        final corpo = jsonDecode(request.body) as Map<String, dynamic>;
        expect(corpo['refreshToken'], 'refresh-antigo');
        return _jsonOk({
          'usuario': _usuarioMap(),
          'accessToken': 'novo-access',
          'refreshToken': 'novo-refresh',
        });
      });

      final service = BackendAuthService(
        apiClient: ApiClient(httpClient: client, tokenStorage: storage),
        tokenStorage: storage,
      );

      final sessao = await service.refresh();

      expect(sessao?.accessToken, 'novo-access');
      expect(await storage.lerAccessToken(), 'novo-access');
      expect(await storage.lerRefreshToken(), 'novo-refresh');
    });

    test('logout limpa o storage mesmo se a chamada de rede falhar', () async {
      await storage.salvar(accessToken: 'a', refreshToken: 'r');

      final client = MockClient((request) async {
        throw const SocketExceptionFalsa();
      });

      final service = BackendAuthService(
        apiClient: ApiClient(httpClient: client, tokenStorage: storage),
        tokenStorage: storage,
      );

      await service.logout();

      expect(await storage.lerAccessToken(), isNull);
      expect(await storage.lerRefreshToken(), isNull);
    });
  });
}

class SocketExceptionFalsa implements Exception {
  const SocketExceptionFalsa();
}
