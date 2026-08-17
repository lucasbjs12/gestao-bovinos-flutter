import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_bovinos_app/core/api/api_client.dart';
import 'package:gestao_bovinos_app/features/auth/auth_provider.dart';
import 'package:gestao_bovinos_app/features/auth/data/backend_auth_service.dart';
import 'package:gestao_bovinos_app/features/auth/presentation/verificacao_email_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import '../helpers/token_storage_falso.dart';

Map<String, dynamic> _envelope(dynamic data) => {'success': true, 'data': data};

Map<String, dynamic> _perfilNaoVerificado() => {
  'usuario': {
    'id': 'u1',
    'nome': 'Lucas',
    'email': 'lucas@teste.com',
    'isAdmin': false,
    'emailVerificado': false,
    'statusAssinatura': 'ativo',
  },
  'fazendaPropria': {'id': 'f1', 'donoId': 'u1', 'nome': 'Fazenda Teste'},
};

/// Sobe a tela com um [AuthProvider] real, mas falando com um [MockClient]
/// em vez do backend de verdade -- evita rede/plugins de plataforma em
/// `flutter test`, igual ao padrão já usado nos testes de sync.
Future<AuthProvider> _bombear(
  WidgetTester tester, {
  required http.Client httpClient,
}) async {
  final tokenStorage = TokenStorageFalso();
  await tokenStorage.salvar(accessToken: 'token-falso', refreshToken: 'refresh-falso');

  final apiClient = ApiClient(httpClient: httpClient, tokenStorage: tokenStorage);
  final authService = BackendAuthService(apiClient: apiClient, tokenStorage: tokenStorage);
  final authProvider = AuthProvider(authService: authService);

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: authProvider,
      child: const MaterialApp(home: VerificacaoEmailScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return authProvider;
}

void main() {
  testWidgets('mostra o e-mail do usuário e o texto de instrução', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/me')) {
        return http.Response(jsonEncode(_envelope(_perfilNaoVerificado())), 200);
      }
      return http.Response(jsonEncode(_envelope(null)), 200);
    });

    await _bombear(tester, httpClient: client);

    expect(find.text('Confirme seu e-mail'), findsOneWidget);
    expect(find.text('lucas@teste.com'), findsOneWidget);
    expect(find.text('Já confirmei'), findsOneWidget);
    expect(find.text('Reenviar e-mail'), findsOneWidget);
  });

  testWidgets('mostra a dica de Spam/aba "Outras" do Outlook', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/me')) {
        return http.Response(jsonEncode(_envelope(_perfilNaoVerificado())), 200);
      }
      return http.Response(jsonEncode(_envelope(null)), 200);
    });

    await _bombear(tester, httpClient: client);

    expect(find.textContaining('aba "Outras"'), findsOneWidget);
  });

  testWidgets('"Já confirmei" antes do link mostra aviso e continua na tela', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/me')) {
        return http.Response(jsonEncode(_envelope(_perfilNaoVerificado())), 200);
      }
      return http.Response(jsonEncode(_envelope(null)), 200);
    });

    await _bombear(tester, httpClient: client);

    await tester.tap(find.text('Já confirmei'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ainda não confirmado. Abra o link no seu e-mail e tente de novo.'),
      findsOneWidget,
    );
  });

  testWidgets('"Reenviar e-mail" com sucesso mostra confirmação', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/me')) {
        return http.Response(jsonEncode(_envelope(_perfilNaoVerificado())), 200);
      }
      if (request.url.path.endsWith('/auth/reenviar-verificacao')) {
        return http.Response(jsonEncode(_envelope(null)), 200);
      }
      return http.Response(jsonEncode(_envelope(null)), 200);
    });

    await _bombear(tester, httpClient: client);

    await tester.tap(find.text('Reenviar e-mail'));
    await tester.pumpAndSettle();

    expect(find.text('E-mail de confirmação reenviado.'), findsOneWidget);
  });

  testWidgets('"Reenviar e-mail" com falha mostra o erro', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/me')) {
        return http.Response(jsonEncode(_envelope(_perfilNaoVerificado())), 200);
      }
      if (request.url.path.endsWith('/auth/reenviar-verificacao')) {
        return http.Response(
          jsonEncode({
            'success': false,
            'message': 'Envio de e-mail nao configurado neste ambiente',
          }),
          503,
        );
      }
      return http.Response(jsonEncode(_envelope(null)), 200);
    });

    await _bombear(tester, httpClient: client);

    await tester.tap(find.text('Reenviar e-mail'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Erro ao reenviar:'), findsOneWidget);
  });
}
