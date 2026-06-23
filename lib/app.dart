import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/db/app_database.dart';
import 'core/routes/app_routes.dart';
import 'core/sync/sync_status_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/presentation/cadastro_fazenda_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/verificacao_email_screen.dart';
import 'features/bovinos/bovinos_provider.dart';
import 'features/bovinos/presentation/animais_baixados_screen.dart';
import 'features/bovinos/presentation/cadastro_bovino_screen.dart';
import 'features/bovinos/presentation/detalhe_bovino_screen.dart';
import 'features/bovinos/presentation/sem_manejo_screen.dart';
import 'features/bovinos/presentation/terneiros_indefinidos_screen.dart';
import 'features/perfil/presentation/perfil_screen.dart';
import 'features/home/home_provider.dart';
import 'features/eventos_sanitarios/eventos_sanitarios_provider.dart';
import 'features/eventos_sanitarios/presentation/cadastro_evento_screen.dart';
import 'features/eventos_sanitarios/presentation/detalhe_evento_screen.dart';
import 'features/invernadas/invernadas_provider.dart';
import 'features/invernadas/presentation/cadastro_invernada_screen.dart';
import 'features/invernadas/presentation/detalhe_invernada_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/shell/presentation/main_shell_screen.dart';
import 'features/shell/shell_provider.dart';
import 'sync/initial_sync_service.dart';
import 'sync/realtime_sync_service.dart';

class GestaoBovinosApp extends StatelessWidget {
  const GestaoBovinosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ShellProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => BovinosProvider()),
        ChangeNotifierProvider(create: (_) => InvernadasProvider()),
        ChangeNotifierProvider(create: (_) => EventosSanitariosProvider()),
        ChangeNotifierProvider(create: (_) => SyncStatusService()),
      ],
      child: MaterialApp(
        title: 'Gestão de Rebanho',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const _AuthGate(),
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case AppRoutes.cadastroFazenda:
              return MaterialPageRoute(
                builder: (_) => const CadastroFazendaScreen(),
                settings: settings,
              );
            case AppRoutes.cadastroBovino:
              return MaterialPageRoute(
                builder: (_) => const CadastroBovinoScreen(),
                settings: settings,
              );
            case AppRoutes.detalheBovino:
              return MaterialPageRoute(
                builder: (_) => const DetalheBovinoScreen(),
                settings: settings,
              );
            case AppRoutes.cadastroInvernada:
              return MaterialPageRoute(
                builder: (_) => const CadastroInvernadaScreen(),
                settings: settings,
              );
            case AppRoutes.detalheInvernada:
              return MaterialPageRoute(
                builder: (_) => const DetalheInvernadaScreen(),
                settings: settings,
              );
            case AppRoutes.cadastroEvento:
              return MaterialPageRoute(
                builder: (_) => const CadastroEventoScreen(),
                settings: settings,
              );
            case AppRoutes.detalheEvento:
              return MaterialPageRoute(
                builder: (_) => const DetalheEventoScreen(),
                settings: settings,
              );
            case AppRoutes.semManejo:
              return MaterialPageRoute(
                builder: (_) => const SemManejoScreen(),
                settings: settings,
              );
            case AppRoutes.terneirosIndefinidos:
              return MaterialPageRoute(
                builder: (_) => const TerneirosIndefinidosScreen(),
                settings: settings,
              );
            case AppRoutes.animaisBaixados:
              return MaterialPageRoute(
                builder: (_) => const AnimaisBaixadosScreen(),
                settings: settings,
              );
            case AppRoutes.perfil:
              return MaterialPageRoute(
                builder: (_) => const PerfilScreen(),
                settings: settings,
              );
            default:
              return null;
          }
        },
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  String? _syncUid;
  RealtimeSyncService? _realtimeSync;
  bool? _onboardingMostrado;

  @override
  void dispose() {
    _realtimeSync?.stop();
    super.dispose();
  }

  Future<void> _verificarOnboarding() async {
    final mostrado = await onboardingJaMostrado();
    if (mounted) setState(() => _onboardingMostrado = mostrado);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final uid = auth.currentUser?.uid;

    if (auth.status == AuthStatus.authenticated && uid != null && uid != _syncUid) {
      _syncUid = uid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _iniciarSync(uid);
          if (_onboardingMostrado == null) _verificarOnboarding();
        }
      });
    } else if (auth.status != AuthStatus.authenticated && _syncUid != null) {
      _syncUid = null;
      _realtimeSync?.stop();
      _realtimeSync = null;
      _onboardingMostrado = null;
    }

    return switch (auth.status) {
      AuthStatus.loading => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      AuthStatus.unauthenticated => const LoginScreen(),
      AuthStatus.unverified => const VerificacaoEmailScreen(),
      AuthStatus.authenticated => _onboardingMostrado == false
          ? OnboardingScreen(
              onConcluir: () => setState(() => _onboardingMostrado = true),
            )
          : const MainShellScreen(),
    };
  }

  Future<void> _iniciarSync(String uid) async {
    final syncService = context.read<SyncStatusService>();
    syncService.iniciar();

    try {
      final db = await AppDatabase.instance.instanceFor(uid);

      if (!await InitialSyncService.jaSincronizou(uid)) {
        await InitialSyncService.sincronizar(uid: uid, db: db);
        if (mounted) {
          context.read<BovinosProvider>().recarregar();
          context.read<InvernadasProvider>().carregar(uid);
          context.read<EventosSanitariosProvider>().carregar(uid);
          context.read<HomeProvider>().carregar(uid);
        }
      }

      _realtimeSync = RealtimeSyncService()..start(uid: uid, db: db);
    } catch (_) {
      // Falha no sync inicial (ex.: offline) — tenta de novo na próxima abertura.
    }
  }
}
