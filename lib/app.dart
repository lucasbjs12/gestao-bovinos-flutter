import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/db/app_database.dart';
import 'core/routes/app_routes.dart';
import 'core/sync/sync_status_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/presentation/cadastro_convidado_screen.dart';
import 'features/auth/presentation/cadastro_fazenda_screen.dart';
import 'features/auth/presentation/convidado_entrar_screen.dart';
import 'features/auth/presentation/escolha_cadastro_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/verificacao_email_screen.dart';
import 'features/bovinos/bovinos_provider.dart';
import 'features/bovinos/presentation/animais_baixados_screen.dart';
import 'features/bovinos/presentation/cadastro_bovino_screen.dart';
import 'features/bovinos/presentation/cadastro_lote_screen.dart';
import 'features/bovinos/presentation/detalhe_bovino_screen.dart';
// import 'features/admin/data/assinatura_service.dart';
// import 'features/admin/data/usuario_assinatura.dart';
// import 'features/admin/presentation/acesso_bloqueado_screen.dart';
import 'features/admin/presentation/painel_admin_screen.dart';
import 'features/bovinos/presentation/personalizar_cadastro_screen.dart';
import 'features/bovinos/presentation/sem_manejo_screen.dart';
import 'features/bovinos/presentation/terneiros_indefinidos_screen.dart';
import 'features/atividades/presentation/diario_atividades_screen.dart';
import 'features/fazenda/presentation/fazenda_ativa_screen.dart';
import 'features/fazenda/presentation/membros_screen.dart';
import 'features/perfil/presentation/perfil_screen.dart';
import 'features/home/home_provider.dart';
import 'features/eventos_sanitarios/eventos_sanitarios_provider.dart';
import 'features/eventos_sanitarios/presentation/cadastro_evento_screen.dart';
import 'features/eventos_sanitarios/presentation/detalhe_evento_screen.dart';
import 'features/invernadas/invernadas_provider.dart';
import 'features/invernadas/presentation/cadastro_invernada_screen.dart';
import 'features/invernadas/presentation/detalhe_invernada_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/planos/assinatura_provider.dart';
import 'features/planos/presentation/planos_screen.dart';
import 'features/shell/presentation/main_shell_screen.dart';
import 'features/shell/shell_provider.dart';
import 'sync/categoria_progressao_service.dart';
import 'sync/polling_sync_service.dart';

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
        ChangeNotifierProvider(create: (_) => AssinaturaProvider()),
        ChangeNotifierProvider(create: (_) => SyncStatusService()),
      ],
      child: MaterialApp(
        title: 'Gestão de Rebanho',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('pt', 'BR')],
        home: const _AuthGate(),
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case AppRoutes.escolhaCadastro:
              return MaterialPageRoute(
                builder: (_) => const EscolhaCadastroScreen(),
                settings: settings,
              );
            case AppRoutes.cadastroFazenda:
              return MaterialPageRoute(
                builder: (_) => const CadastroFazendaScreen(),
                settings: settings,
              );
            case AppRoutes.cadastroConvidado:
              return MaterialPageRoute(
                builder: (_) => const CadastroConvidadoScreen(),
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
            case AppRoutes.cadastroLote:
              return MaterialPageRoute(
                builder: (_) => const CadastroLoteScreen(),
                settings: settings,
              );
            case AppRoutes.personalizarCadastro:
              return MaterialPageRoute(
                builder: (_) => const PersonalizarCadastroScreen(),
                settings: settings,
              );
            case AppRoutes.painelAdmin:
              return MaterialPageRoute(
                builder: (_) => const PainelAdminScreen(),
                settings: settings,
              );
            case AppRoutes.diarioAtividades:
              return MaterialPageRoute(
                builder: (_) => const DiarioAtividadesScreen(),
                settings: settings,
              );
            case AppRoutes.membros:
              return MaterialPageRoute(
                builder: (_) => const MembrosScreen(),
                settings: settings,
              );
            case AppRoutes.fazendaAtiva:
              return MaterialPageRoute(
                builder: (_) => const FazendaAtivaScreen(),
                settings: settings,
              );
            case AppRoutes.planos:
              return MaterialPageRoute(
                builder: (_) => const PlanosScreen(),
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
  String? _syncFazendaId;
  PollingSyncService? _pollingSync;
  bool? _onboardingMostrado;

  @override
  void dispose() {
    _pollingSync?.stop();
    super.dispose();
  }

  Future<void> _verificarOnboarding() async {
    final mostrado = await onboardingJaMostrado();
    if (mounted) setState(() => _onboardingMostrado = mostrado);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final fazendaId = auth.fazendaId;

    // Dispara ao logar E ao trocar de fazenda (fazendaId muda).
    if (auth.status == AuthStatus.authenticated &&
        fazendaId != null &&
        fazendaId != _syncFazendaId) {
      _syncFazendaId = fazendaId;
      _pollingSync?.stop();
      _pollingSync = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _iniciarSync(fazendaId);
          if (_onboardingMostrado == null) _verificarOnboarding();
        }
      });
    } else if (auth.status != AuthStatus.authenticated && _syncFazendaId != null) {
      _syncFazendaId = null;
      _pollingSync?.stop();
      _pollingSync = null;
      _onboardingMostrado = null;
    }

    return switch (auth.status) {
      AuthStatus.loading => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      AuthStatus.unauthenticated => const LoginScreen(),
      AuthStatus.unverified => const VerificacaoEmailScreen(),
      AuthStatus.authenticated => _telaAutenticado(auth),
    };
  }

  Widget _telaAutenticado(AuthProvider auth) {
    // Convidado sem fazenda: sistema bloqueado até inserir um código válido.
    if (auth.precisaEntrarEmFazenda) {
      return const ConvidadoEntrarScreen();
    }
    // Onboarding é sobre "a sua fazenda" — só para produtor.
    if (!auth.ehConvidado && _onboardingMostrado == false) {
      return OnboardingScreen(
        onConcluir: () => setState(() => _onboardingMostrado = true),
      );
    }
    return const MainShellScreen();
  }

  Future<void> _iniciarSync(String fazendaId) async {
    final syncService = context.read<SyncStatusService>();
    syncService.iniciar();
    // Assim que a conexão voltar, tenta esvaziar a fila de pendências na
    // hora em vez de esperar o próximo ciclo do polling (até 45s).
    syncService.aoReconectar = () => _pollingSync?.sincronizarAgora();

    try {
      final db = await AppDatabase.instance.instanceFor(fazendaId);

      // A primeira rodada do polling já é a sync inicial -- espera ela
      // terminar antes de carregar os providers, senão a tela abre vazia.
      _pollingSync = PollingSyncService();
      await _pollingSync!.start(uid: fazendaId, db: db, sync: syncService);

      if (mounted) {
        // carregar(fazendaId) — não recarregar() — para não reusar o uid
        // anterior (que reabriria o banco da fazenda errada).
        context.read<BovinosProvider>().carregar(fazendaId);
        context.read<InvernadasProvider>().carregar(fazendaId);
        context.read<EventosSanitariosProvider>().carregar(fazendaId);
        context.read<HomeProvider>().carregar(fazendaId);
        context.read<AssinaturaProvider>().carregar(fazendaId);
      }

      // Progressão de categoria por idade (roda toda vez que o app abre)
      final promovidos =
          await CategoriaProgressaoService.executar(uid: fazendaId, db: db);
      if (mounted && promovidos.isNotEmpty) {
        context.read<BovinosProvider>().recarregar();
        context.read<HomeProvider>().carregar(fazendaId);

        final n   = promovidos.length;
        final msg = n == 1
            ? '${promovidos.first.brinco}: ${promovidos.first.categoriaAnterior} → ${promovidos.first.categoriaNova}'
            : '$n animais tiveram categoria atualizada automaticamente';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      // Falha no sync inicial (ex.: offline) — tenta de novo na próxima abertura.
    }
  }
}
