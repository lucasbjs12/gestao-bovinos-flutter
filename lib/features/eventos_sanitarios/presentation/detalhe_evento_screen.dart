import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/db/app_database.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/sync/sync_status_service.dart';
import '../../auth/auth_provider.dart';
import '../../bovinos/data/bovino.dart';
import '../../home/home_provider.dart';
import '../data/evento_sanitario_completo.dart';
import '../data/evento_sanitario_local_repository.dart';
import '../data/evento_sanitario_remote_repository.dart';
import '../eventos_sanitarios_provider.dart';

class DetalheEventoScreen extends StatefulWidget {
  const DetalheEventoScreen({super.key});

  @override
  State<DetalheEventoScreen> createState() => _DetalheEventoScreenState();
}

class _DetalheEventoScreenState extends State<DetalheEventoScreen> {
  EventoSanitarioCompleto? _evento;
  List<Bovino> _bovinos = [];
  bool _carregando = true;
  String? _uid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  Future<void> _carregar() async {
    _uid = context.read<AuthProvider>().currentUser?.uid;
    final id = ModalRoute.of(context)?.settings.arguments as int?;
    if (id == null || _uid == null) {
      setState(() => _carregando = false);
      return;
    }
    final db = await AppDatabase.instance.instanceFor(_uid);
    final evento =
        await EventoSanitarioLocalRepository(db).buscarCompletoPorId(id);
    final bovinos =
        await EventoSanitarioLocalRepository(db).listarBovinosDoEvento(id);
    if (mounted) {
      setState(() {
        _evento = evento;
        _bovinos = bovinos;
        _carregando = false;
      });
    }
  }

  Future<void> _editar() async {
    await Navigator.pushNamed(
      context,
      AppRoutes.cadastroEvento,
      arguments: _evento!.id,
    );
    if (!mounted) return;
    await _carregar();
  }

  Future<void> _confirmarExclusao() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir evento?'),
        content:
            const Text('Este evento será removido. Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    final uid = _uid!;
    final evento = _evento!;
    final syncSvc = context.read<SyncStatusService>();
    final provider = context.read<EventosSanitariosProvider>();

    final db = await AppDatabase.instance.instanceFor(uid);
    await EventoSanitarioLocalRepository(db).excluir(evento.id);

    EventoSanitarioRemoteRepository(uid: uid, sync: syncSvc)
        .excluir(evento.syncId);

    provider.recarregar();
    if (mounted) context.read<HomeProvider>().carregar(uid);

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_evento == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Evento não encontrado.')),
      );
    }

    final cor = _corPorTipo(_evento!.tipo);

    return Scaffold(
      appBar: AppBar(
        title: Text(_evento!.tipo),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar',
            onPressed: _editar,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Excluir',
            onPressed: _confirmarExclusao,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          // ── Detalhes ──────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: cor.withValues(alpha: 0.15),
                        child: Icon(_iconePorTipo(_evento!.tipo), color: cor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _evento!.tipo,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  if (_evento!.dataEvento != null) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                        icon: Icons.calendar_today_outlined,
                        label: _evento!.dataEvento!),
                  ],
                  if (_evento!.invernadaDescricao != null) ...[
                    const SizedBox(height: 6),
                    _InfoRow(
                        icon: Icons.fence_outlined,
                        label: _evento!.invernadaDescricao!),
                  ],
                  if (_evento!.produtoUtilizado != null) ...[
                    const SizedBox(height: 6),
                    _InfoRow(
                        icon: Icons.science_outlined,
                        label: _evento!.produtoUtilizado!),
                  ],
                  if (_evento!.dosagem != null) ...[
                    const SizedBox(height: 6),
                    _InfoRow(
                        icon: Icons.straighten_outlined,
                        label: _evento!.dosagem!),
                  ],
                  if (_evento!.responsavel != null) ...[
                    const SizedBox(height: 6),
                    _InfoRow(
                        icon: Icons.person_outlined,
                        label: _evento!.responsavel!),
                  ],
                  if (_evento!.observacoes != null) ...[
                    const Divider(height: 20),
                    Text(
                      _evento!.observacoes!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Animais ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              'Animais (${_bovinos.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),

          if (_bovinos.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Nenhum animal vinculado.')),
            )
          else
            ..._bovinos.map(
              (b) => Card(
                margin: const EdgeInsets.symmetric(vertical: 3),
                child: ListTile(
                  leading: _buildFoto(b.foto),
                  title: Text(b.nomeAnimal ?? b.numeroBrinco),
                  subtitle: Text(
                    [
                      if (b.nomeAnimal != null) b.numeroBrinco,
                      if (b.categoria != null) b.categoria!,
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.pushNamed(
                      context,
                      AppRoutes.detalheBovino,
                      arguments: b.id,
                    );
                    if (mounted) await _carregar();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFoto(String? foto) {
    if (foto == null) {
      return const CircleAvatar(child: Icon(Icons.pets_outlined));
    }
    if (foto.startsWith('http')) {
      return CircleAvatar(backgroundImage: CachedNetworkImageProvider(foto));
    }
    return CircleAvatar(backgroundImage: FileImage(File(foto)));
  }
}

// ─── Info Row ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Color _corPorTipo(String tipo) => switch (tipo) {
      'Vacinação'    => const Color(0xFF1565C0),
      'Vermifugação' => const Color(0xFF2E7D32),
      'Medicação'    => const Color(0xFFE65100),
      'Castração'    => const Color(0xFF6A1B9A),
      'Banho'        => const Color(0xFF00838F),
      _              => const Color(0xFF455A64),
    };

IconData _iconePorTipo(String tipo) => switch (tipo) {
      'Vacinação'    => Icons.vaccines_outlined,
      'Vermifugação' => Icons.bug_report_outlined,
      'Medicação'    => Icons.medication_outlined,
      'Castração'    => Icons.content_cut_outlined,
      'Banho'        => Icons.water_drop_outlined,
      _              => Icons.medical_services_outlined,
    };
