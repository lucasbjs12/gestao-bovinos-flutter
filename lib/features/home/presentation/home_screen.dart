import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/sync/sync_status_service.dart';
import '../../auth/auth_provider.dart';
import '../../shell/shell_provider.dart';
import '../home_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _diasPtBr = [
    'Domingo', 'Segunda-feira', 'Terça-feira',
    'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado',
  ];
  static const _mesesPtBr = [
    '', 'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
    'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  void _carregar() {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid != null) context.read<HomeProvider>().carregar(uid);
  }

  String _saudacao() {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Bom dia,';
    if (hora < 18) return 'Boa tarde,';
    return 'Boa noite,';
  }

  String _dataFormatada() {
    final now = DateTime.now();
    final nomeDia = _diasPtBr[now.weekday % 7];
    final nomeMes = _mesesPtBr[now.month];
    final dia = now.day.toString().padLeft(2, '0');
    final cap = nomeDia[0].toUpperCase() + nomeDia.substring(1);
    return '$cap, $dia de $nomeMes';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final home = context.watch<HomeProvider>();
    final sync = context.watch<SyncStatusService>();
    final nomeFazenda = auth.currentUser?.displayName ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F0),
      body: Column(
        children: [
          _Header(
            saudacao: _saudacao(),
            nomeFazenda: nomeFazenda,
            data: _dataFormatada(),
            syncEstado: sync.estado,
          ),
          Expanded(
            child: home.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _DashboardContent(stats: home.stats),
          ),
        ],
      ),
    );
  }
}

// ─── Header com gradiente ────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String saudacao;
  final String nomeFazenda;
  final String data;
  final SyncEstado syncEstado;

  const _Header({
    required this.saudacao,
    required this.nomeFazenda,
    required this.data,
    required this.syncEstado,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Círculos decorativos
          Positioned(
            right: -28,
            top: -18,
            child: Container(
              width: 160,
              height: 160,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x0DFFFFFF),
              ),
            ),
          ),
          Positioned(
            right: 60,
            top: 55,
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x08FFFFFF),
              ),
            ),
          ),
          // Conteúdo
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPadding + 18, 14, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        saudacao,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xB2FFFFFF),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nomeFazenda.isEmpty ? 'Minha Fazenda' : nomeFazenda,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0x8FFFFFFF),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SyncChip(estado: syncEstado),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  decoration: const BoxDecoration(
                    color: Color(0x26FFFFFF),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.person_outline,
                        color: Colors.white, size: 22),
                    tooltip: 'Perfil',
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: false)
                            .pushNamed(AppRoutes.perfil),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chip de sincronização ───────────────────────────────────────────────────

class _SyncChip extends StatelessWidget {
  final SyncEstado estado;
  const _SyncChip({required this.estado});

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (estado) {
      SyncEstado.sincronizado  => (Icons.cloud_done_outlined, 'Sincronizado'),
      SyncEstado.sincronizando => (Icons.sync, 'Sincronizando…'),
      SyncEstado.offline       => (Icons.cloud_off_outlined, 'Sem conexão'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x26FFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dashboard scrollável ────────────────────────────────────────────────────

class _DashboardContent extends StatelessWidget {
  final DashboardStats stats;

  const _DashboardContent({required this.stats});

  @override
  Widget build(BuildContext context) {
    final semManejoVisivel = stats.semManejo > 0;
    final indefinidosVisivel = stats.indefinidos > 0;
    final atencaoVisivel = semManejoVisivel || indefinidosVisivel;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card total do rebanho
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: _RebanhoCard(stats: stats),
          ),

          // Acesso rápido
          const _SectionLabel('ACESSO RÁPIDO'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _AcessoRapidoGrid(
              onBovinos:    () => context.read<ShellProvider>().setAba(1),
              onInvernadas: () => context.read<ShellProvider>().setAba(2),
              onSanitario:  () => context.read<ShellProvider>().setAba(3),
              onRfid:       () => context.read<ShellProvider>().setAba(4),
            ),
          ),

          // Animais baixados
          const _SectionLabel('HISTÓRICO'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _BaixadosCard(
              count: stats.baixados,
              onTap: () => Navigator.of(context, rootNavigator: false)
                  .pushNamed(AppRoutes.animaisBaixados),
            ),
          ),

          // Atenção necessária
          if (atencaoVisivel) ...[
            const _SectionLabel('ATENÇÃO NECESSÁRIA'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _AtencaoCard(
                semManejoCount:     stats.semManejo,
                indefinidosCount:   stats.indefinidos,
                semManejoVisivel:   semManejoVisivel,
                indefinidosVisivel: indefinidosVisivel,
                onSemManejo: () => Navigator.of(context, rootNavigator: false)
                    .pushNamed(AppRoutes.semManejo),
                onIndefinidos: () => Navigator.of(context, rootNavigator: false)
                    .pushNamed(AppRoutes.terneirosIndefinidos),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Card: Total do Rebanho ──────────────────────────────────────────────────

class _RebanhoCard extends StatelessWidget {
  final DashboardStats stats;
  const _RebanhoCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Header verde com total
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL DO REBANHO',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                            color: Color(0xB8FFFFFF),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${stats.totalRebanho}',
                              style: const TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(left: 8, bottom: 8),
                              child: Text(
                                'animais ativos',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xCCFFFFFF),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.pets, size: 54, color: Color(0x30FFFFFF)),
                ],
              ),
            ),
            // Corpo branco com categorias
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _CategoriaChip(
                          label: 'Vacas',
                          count: stats.vacas,
                          dotColor: const Color(0xFF2E7D32),
                          marginEnd: 5,
                          onTap: () => context.read<ShellProvider>().setAba(1),
                        ),
                      ),
                      Expanded(
                        child: _CategoriaChip(
                          label: 'Novilhos/as',
                          count: stats.novilhos,
                          dotColor: const Color(0xFF1976D2),
                          marginStart: 5,
                          onTap: () => context.read<ShellProvider>().setAba(1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _CategoriaChip(
                          label: 'Terneiros',
                          count: stats.terneiros,
                          dotColor: const Color(0xFFE65100),
                          marginEnd: 5,
                          onTap: () => context.read<ShellProvider>().setAba(1),
                        ),
                      ),
                      Expanded(
                        child: _CategoriaChip(
                          label: 'Outros',
                          count: stats.outros,
                          dotColor: const Color(0xFF757575),
                          marginStart: 5,
                          onTap: () => context.read<ShellProvider>().setAba(1),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoriaChip extends StatelessWidget {
  final String label;
  final int count;
  final Color dotColor;
  final double marginStart;
  final double marginEnd;
  final VoidCallback? onTap;

  const _CategoriaChip({
    required this.label,
    required this.count,
    required this.dotColor,
    this.marginStart = 0,
    this.marginEnd = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsetsDirectional.only(start: marginStart, end: marginEnd),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8E2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: count > 0 ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: dotColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF424242),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: count > 0 ? dotColor : const Color(0xFFBDBDBD),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Label de seção ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w700,
          color: Color(0xFF5C6B5C),
        ),
      ),
    );
  }
}

// ─── Grade de acesso rápido ──────────────────────────────────────────────────

class _AcessoRapidoGrid extends StatelessWidget {
  final VoidCallback onBovinos;
  final VoidCallback onInvernadas;
  final VoidCallback onSanitario;
  final VoidCallback onRfid;

  const _AcessoRapidoGrid({
    required this.onBovinos,
    required this.onInvernadas,
    required this.onSanitario,
    required this.onRfid,
  });

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<HomeProvider>().stats;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _NavCard(
                icon: Icons.pets,
                iconBg: const Color(0xFFE8F5E9),
                iconColor: const Color(0xFF2E7D32),
                titulo: 'Bovinos',
                subtitulo: stats.totalRebanho == 1
                    ? '1 animal'
                    : '${stats.totalRebanho} animais',
                marginEnd: 6,
                onTap: onBovinos,
              ),
            ),
            Expanded(
              child: _NavCard(
                icon: Icons.fence_outlined,
                iconBg: const Color(0xFFE3F2FD),
                iconColor: const Color(0xFF1565C0),
                titulo: 'Invernadas',
                subtitulo: stats.invernadas == 1
                    ? '1 ativa'
                    : '${stats.invernadas} ativas',
                marginStart: 6,
                onTap: onInvernadas,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _NavCard(
                icon: Icons.medical_services_outlined,
                iconBg: const Color(0xFFFFF3E0),
                iconColor: const Color(0xFFE65100),
                titulo: 'Sanitário',
                subtitulo: 'Ver manejos',
                marginEnd: 6,
                onTap: onSanitario,
              ),
            ),
            Expanded(
              child: _NavCard(
                icon: Icons.nfc,
                iconBg: const Color(0xFFF3E5F5),
                iconColor: const Color(0xFF6A1B9A),
                titulo: 'RFID',
                subtitulo: 'Leitura rápida',
                marginStart: 6,
                onTap: onRfid,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String titulo;
  final String subtitulo;
  final double marginStart;
  final double marginEnd;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
    this.marginStart = 0,
    this.marginEnd = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsetsDirectional.only(start: marginStart, end: marginEnd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(height: 14),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1C1A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitulo,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8E9490),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Card: Animais Baixados ──────────────────────────────────────────────────

class _BaixadosCard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _BaixadosCard({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.archive_outlined,
                      color: Color(0xFF616161), size: 24),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Animais baixados',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1C1A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Vendidos, mortos, abatidos…',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8E9490),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF424242),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Card: Atenção Necessária ────────────────────────────────────────────────

class _AtencaoCard extends StatelessWidget {
  final int semManejoCount;
  final int indefinidosCount;
  final bool semManejoVisivel;
  final bool indefinidosVisivel;
  final VoidCallback onSemManejo;
  final VoidCallback onIndefinidos;

  const _AtencaoCard({
    required this.semManejoCount,
    required this.indefinidosCount,
    required this.semManejoVisivel,
    required this.indefinidosVisivel,
    required this.onSemManejo,
    required this.onIndefinidos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (semManejoVisivel)
            _AlertaItem(
              iconBg: const Color(0xFFFFF3E0),
              iconColor: const Color(0xFFE65100),
              icon: Icons.schedule_outlined,
              titulo: 'Sem manejo sanitário',
              subtitulo: 'Há mais de 30 dias',
              count: semManejoCount,
              countColor: const Color(0xFFE65100),
              onTap: onSemManejo,
            ),
          if (semManejoVisivel && indefinidosVisivel)
            const Divider(height: 1, indent: 76),
          if (indefinidosVisivel)
            _AlertaItem(
              iconBg: const Color(0xFFF3E5F5),
              iconColor: const Color(0xFF6A1B9A),
              icon: Icons.help_outline,
              titulo: 'Sexo não definido',
              subtitulo: 'Terneiros sem categoria',
              count: indefinidosCount,
              countColor: const Color(0xFF6A1B9A),
              onTap: onIndefinidos,
            ),
        ],
      ),
    );
  }
}

class _AlertaItem extends StatelessWidget {
  final Color iconBg;
  final Color iconColor;
  final IconData icon;
  final String titulo;
  final String subtitulo;
  final int count;
  final Color countColor;
  final VoidCallback onTap;

  const _AlertaItem({
    required this.iconBg,
    required this.iconColor,
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    required this.count,
    required this.countColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1C1A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8E9490),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: countColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: countColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
