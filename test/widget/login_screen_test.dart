import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_bovinos_app/core/api/api_client.dart';
import 'package:gestao_bovinos_app/features/auth/auth_provider.dart';
import 'package:gestao_bovinos_app/features/auth/data/backend_auth_service.dart';
import 'package:gestao_bovinos_app/features/auth/presentation/login_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import '../helpers/token_storage_falso.dart';

Map<String, dynamic> _sucesso(dynamic data) => {'success': true, 'data': data};

Map<String, dynamic> _erro(String mensagem) => {
  'success': false,
  'message': mensagem,
};

/// Sobe a LoginScreen com um AuthProvider real falando com [httpClient]
/// fake -- sem token salvo, então nasce "unauthenticated" (não toca
/// AppDatabase/SharedPreferences, que exigiriam mockar plugins de
/// plataforma à parte).
Future<AuthProvider> _bombear(
  WidgetTester tester, {
  required http.Client httpClient,
}) async {
  // Viewport padrão de teste (800x600) é baixo demais pro card com scroll --
  // o botão "Entrar" fica fora da área visível e tap() falha o hit test.
  tester.view.physicalSize = const Size(480, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final tokenStorage = TokenStorageFalso();
  final apiClient = ApiClient(httpClient: httpClient, tokenStorage: tokenStorage);
  final authService = BackendAuthService(apiClient: apiClient, tokenStorage: tokenStorage);
  final authProvider = AuthProvider(authService: authService);

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: authProvider,
      child: const MaterialApp(home: LoginScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return authProvider;
}

void main() {
  testWidgets('não estoura em telas estreitas (360dp, comum em Android)', (tester) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = MockClient((_) async => http.Response('', 501));
    final tokenStorage = TokenStorageFalso();
    final apiClient = ApiClient(httpClient: client, tokenStorage: tokenStorage);
    final authService = BackendAuthService(apiClient: apiClient, tokenStorage: tokenStorage);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: AuthProvider(authService: authService),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('renderiza os campos e o botão Entrar', (tester) async {
    final client = MockClient((_) async => http.Response('', 501));
    await _bombear(tester, httpClient: client);

    expect(find.text('Acesse sua conta'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('submeter vazio mostra erro de validação e não chama a API', (tester) async {
    var chamou = false;
    final client = MockClient((_) async {
      chamou = true;
      return http.Response('', 501);
    });
    await _bombear(tester, httpClient: client);

    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Informe o e-mail.'), findsOneWidget);
    expect(find.text('Informe a senha.'), findsOneWidget);
    expect(chamou, isFalse);
  });

  testWidgets('login com senha errada mostra a mensagem de erro do backend', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/login')) {
        return http.Response(jsonEncode(_erro('Credenciais invalidas')), 401);
      }
      return http.Response('', 501);
    });
    final authProvider = await _bombear(tester, httpClient: client);

    await tester.enterText(
      find.byType(TextFormField).first,
      'lucas@teste.com',
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      'senha-errada',
    );
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('E-mail ou senha inválidos.'), findsOneWidget);
    expect(authProvider.status, AuthStatus.unauthenticated);
  });

  testWidgets('login com sucesso mas e-mail não verificado atualiza o provider', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/login')) {
        return http.Response(
          jsonEncode(_sucesso({
            'usuario': {
              'id': 'u1',
              'nome': 'Lucas',
              'email': 'lucas@teste.com',
              'isAdmin': false,
              'emailVerificado': false,
              'statusAssinatura': 'ativo',
            },
            'accessToken': 'acc',
            'refreshToken': 'ref',
          })),
          200,
        );
      }
      if (request.url.path.endsWith('/auth/me')) {
        return http.Response(
          jsonEncode(_sucesso({
            'usuario': {
              'id': 'u1',
              'nome': 'Lucas',
              'email': 'lucas@teste.com',
              'isAdmin': false,
              'emailVerificado': false,
              'statusAssinatura': 'ativo',
            },
            'fazendaPropria': {'id': 'f1', 'donoId': 'u1', 'nome': 'Fazenda'},
          })),
          200,
        );
      }
      return http.Response('', 501);
    });
    final authProvider = await _bombear(tester, httpClient: client);

    await tester.enterText(find.byType(TextFormField).first, 'lucas@teste.com');
    await tester.enterText(find.byType(TextFormField).last, 'senha-certa');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    // Não deve sobrar snackbar de erro -- login funcionou, só o e-mail
    // ainda não foi confirmado (é o _AuthGate quem troca de tela, fora
    // do escopo da LoginScreen em si).
    expect(find.byType(SnackBar), findsNothing);
    expect(authProvider.status, AuthStatus.unverified);
  });

  testWidgets('"Esqueci minha senha" sem e-mail preenchido pede o e-mail', (tester) async {
    final client = MockClient((_) async => http.Response('', 501));
    await _bombear(tester, httpClient: client);

    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();

    expect(
      find.text('Informe o e-mail para recuperar a senha.'),
      findsOneWidget,
    );
  });

  testWidgets('"Esqueci minha senha" com e-mail preenchido confirma o envio', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/esqueci-senha')) {
        return http.Response(jsonEncode(_sucesso(null)), 200);
      }
      return http.Response('', 501);
    });
    await _bombear(tester, httpClient: client);

    await tester.enterText(find.byType(TextFormField).first, 'lucas@teste.com');
    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();

    expect(
      find.text('E-mail de recuperação enviado para lucas@teste.com.'),
      findsOneWidget,
    );
  });
}
