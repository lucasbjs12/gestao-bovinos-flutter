import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/db/app_database.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/sync/sync_status_service.dart';
import '../../../core/utils/photo_service.dart';
import '../../auth/auth_provider.dart';
import '../../eventos_sanitarios/data/evento_sanitario_completo.dart';
import '../../eventos_sanitarios/data/evento_sanitario_local_repository.dart';
import '../../home/home_provider.dart';
import '../bovinos_provider.dart';
import '../data/baixa_bovino.dart';
import '../data/baixa_bovino_remote_repository.dart';
import '../data/bovino.dart';
import '../data/bovino_local_repository.dart';
import '../data/bovino_remote_repository.dart';

class DetalheBovinoScreen extends StatefulWidget {
  const DetalheBovinoScreen({super.key});

  @override
  State<DetalheBovinoScreen> createState() => _DetalheBovinoScreenState();
}

class _DetalheBovinoScreenState extends State<DetalheBovinoScreen> {
  Bovino? _bovino;
  Bovino? _terneiro;
  Bovino? _mae;
  List<EventoSanitarioCompleto> _eventos = [];
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
    final repo = BovinoLocalRepository(db);
    final b = await repo.buscarPorId(id);
    Bovino? terneiro;
    Bovino? mae;
    List<EventoSanitarioCompleto> eventos = [];
    if (b != null) {
      if (b.estaDeCria == 1 && b.id != null) {
        terneiro = await repo.buscarFilhoPorMae(b.id!);
      }
      if (b.idMae != null) {
        mae = await repo.buscarPorId(b.idMae!);
      }
      eventos = await EventoSanitarioLocalRepository(db).listarPorBovino(b.id!);
    }
    if (mounted) {
      setState(() {
        _bovino = b;
        _terneiro = terneiro;
        _mae = mae;
        _eventos = eventos;
        _carregando = false;
      });
    }
  }

  Future<void> _editar() async {
    await Navigator.pushNamed(
      context,
      AppRoutes.cadastroBovino,
      arguments: _bovino!.id,
    );
    if (mounted) await _carregar();
  }

  Future<void> _confirmarExclusao() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir animal'),
        content: Text(
          'Deseja excluir permanentemente o animal ${_bovino?.numeroBrinco}? '
          'Esta ação não pode ser desfeita.',
        ),
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
    if (ok != true || !mounted) return;

    final db = await AppDatabase.instance.instanceFor(_uid);
    await BovinoLocalRepository(db).excluir(_bovino!.id!);
    PhotoService.deleteIfLocal(_bovino!.foto);
    // Fire-and-forget remoção no Firestore
    if (mounted) {
      BovinoRemoteRepository(
        uid: _uid!,
        sync: context.read<SyncStatusService>(),
      ).excluir(_bovino!.syncId);
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _darBaixa() async {
    final resultado = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _DarBaixaSheet(),
    );
    if (resultado == null || !mounted) return;

    final uid = _uid!;
    final bovino = _bovino!;
    final syncSvc = context.read<SyncStatusService>();

    final db = await AppDatabase.instance.instanceFor(uid);
    final bovinoAtualizado = await BovinoLocalRepository(db).darBaixaBovino(
      id: bovino.id!,
      motivo: resultado['motivo'] as String,
      dataBaixa: resultado['dataBaixa'] as String,
      dataBaixaMillis: resultado['dataBaixaMillis'] as int,
      observacoes: resultado['observacoes'] as String?,
    );

    if (!mounted) return;

    BaixaBovinoRemoteRepository(uid: uid, sync: syncSvc).darBaixa(
      bovinoAtualizado,
      BaixaBovino(
        bovinoId: bovino.id!,
        motivo: resultado['motivo'] as String,
        dataBaixa: resultado['dataBaixa'] as String,
        dataBaixaMillis: resultado['dataBaixaMillis'] as int,
        observacoes: resultado['observacoes'] as String?,
      ),
    );

    context.read<BovinosProvider>().recarregar();
    context.read<HomeProvider>().carregar(uid);

    if (mounted) Navigator.pop(context, true);
  }

  String _formatarData(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Future<void> _abrirVincularTerneiro() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _VincularTerneiroSheet(mae: _bovino!, uid: _uid!),
    );
    if (result == true && mounted) {
      context.read<BovinosProvider>().recarregar();
      context.read<HomeProvider>().carregar(_uid!);
      await _carregar();
    }
  }

  Future<void> _desvincularTerneiro() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desvincular terneiro?'),
        content: const Text(
          'O vínculo entre esta vaca e o terneiro será removido. '
          'O terneiro não será excluído.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final db = await AppDatabase.instance.instanceFor(_uid);
    final repo = BovinoLocalRepository(db);
    await repo.desvincularTerneiro(_terneiro!.id!);

    if (mounted) {
      BovinoRemoteRepository(
        uid: _uid!,
        sync: context.read<SyncStatusService>(),
      ).salvar(_terneiro!.copyWith(clearIdMae: true));
      context.read<BovinosProvider>().recarregar();
      context.read<HomeProvider>().carregar(_uid!);
      await _carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_bovino == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Animal não encontrado.')),
      );
    }

    final b = _bovino!;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(b.numeroBrinco),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar',
            onPressed: _editar,
          ),
          PopupMenuButton<String>(
            tooltip: 'Mais opções',
            onSelected: (v) {
              if (v == 'excluir') _confirmarExclusao();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'excluir',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Excluir animal',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header card ──────────────────────────────────────────────
            Card(
              color: cs.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Foto
                    GestureDetector(
                      onTap: b.foto != null
                          ? () => _abrirFotoFullscreen(b.foto!)
                          : null,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: _buildFoto(b.foto),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (b.nomeAnimal != null)
                            Text(
                              b.nomeAnimal!,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          Text(
                            'Brinco: ${b.numeroBrinco}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 4),
                          _StatusBadge(status: b.status),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Dados ────────────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DADOS DO ANIMAL',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoGrid(items: [
                      _InfoItem('Categoria', b.categoria),
                      _InfoItem('Sexo', b.sexo),
                      _InfoItem('Raça', b.raca),
                      _InfoItem('Pelagem', b.pelagem),
                      if (b.dataNascimentoMillis != null)
                        _InfoItem(
                          'Nascimento',
                          _formatarData(b.dataNascimentoMillis!),
                        ),
                      if (b.pesoAtualKg != null)
                        _InfoItem(
                          'Peso',
                          '${b.pesoAtualKg! % 1 == 0 ? b.pesoAtualKg!.toStringAsFixed(0) : b.pesoAtualKg!.toStringAsFixed(1)} kg',
                        ),
                      _InfoItem('Origem', b.origem),
                      _InfoItem('Código EPC', b.codigoEpc),
                      if (b.invernadaDescricao != null)
                        _InfoItem('Invernada', b.invernadaDescricao),
                      if (b.sexo?.toLowerCase() == 'fêmea')
                        _InfoItem(
                          'De cria',
                          b.estaDeCria == 1 ? 'Sim' : 'Não',
                        ),
                    ]),
                  ],
                ),
              ),
            ),

            // ── Vaca mãe ─────────────────────────────────────────────────
            if (_mae != null) ...[
              const SizedBox(height: 12),
              Card(
                color: cs.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VACA MÃE',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w500,
                          color: cs.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.detalheBovino,
                          arguments: _mae!.id,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.female, size: 20, color: cs.onSecondaryContainer),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Brinco: ${_mae!.numeroBrinco}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSecondaryContainer,
                                    ),
                                  ),
                                  if (_mae!.nomeAnimal != null)
                                    Text(
                                      _mae!.nomeAnimal!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: cs.onSecondaryContainer.withAlpha(180),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, size: 18, color: cs.onSecondaryContainer),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // ── Terneiro vinculado ────────────────────────────────────────
            if (b.estaDeCria == 1) ...[
              const SizedBox(height: 12),
              Card(
                color: cs.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TERNEIRO VINCULADO',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w500,
                          color: cs.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_terneiro != null) ...[
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.detalheBovino,
                            arguments: _terneiro!.id,
                          ).then((_) { if (mounted) _carregar(); }),
                          child: Row(
                            children: [
                              Icon(Icons.pets, size: 20, color: cs.onSecondaryContainer),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Brinco: ${_terneiro!.numeroBrinco}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSecondaryContainer,
                                      ),
                                    ),
                                    if (_terneiro!.nomeAnimal != null)
                                      Text(
                                        _terneiro!.nomeAnimal!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: cs.onSecondaryContainer.withAlpha(180),
                                        ),
                                      ),
                                    if (_terneiro!.raca != null)
                                      Text(
                                        _terneiro!.raca!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: cs.onSecondaryContainer.withAlpha(180),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, size: 18, color: cs.onSecondaryContainer),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: _desvincularTerneiro,
                          icon: const Icon(Icons.link_off, size: 16),
                          label: const Text('Desvincular terneiro'),
                          style: TextButton.styleFrom(
                            foregroundColor: cs.error,
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Nenhum terneiro vinculado',
                          style: TextStyle(
                            color: cs.onSecondaryContainer.withAlpha(160),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _abrirVincularTerneiro,
                            icon: const Icon(Icons.link, size: 18),
                            label: const Text('Informar brinco do terneiro'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            // ── Observações ──────────────────────────────────────────────
            if (b.observacoes != null && b.observacoes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OBSERVAÇÕES',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(b.observacoes!),
                    ],
                  ),
                ),
              ),
            ],

            // ── Histórico sanitário ──────────────────────────────────────
            const SizedBox(height: 12),
            _HistoricoSanitarioCard(
              eventos: _eventos,
              onVerEvento: (id) => Navigator.pushNamed(
                context,
                AppRoutes.detalheEvento,
                arguments: id,
              ).then((_) { if (mounted) _carregar(); }),
            ),

            const SizedBox(height: 24),

            // ── Ações ────────────────────────────────────────────────────
            FilledButton.icon(
              onPressed: _editar,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar dados completos'),
            ),
            if (b.status.toLowerCase() != 'inativo') ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF3E0),
                  foregroundColor: const Color(0xFFE65100),
                ),
                onPressed: () async {
                  await Navigator.pushNamed(
                    context,
                    AppRoutes.cadastroEvento,
                    arguments: [b.id!],
                  );
                  if (mounted) await _carregar();
                },
                icon: const Icon(Icons.medical_services_outlined),
                label: const Text('Criar evento sanitário'),
              ),
            ],
            if (b.status.toLowerCase() != 'inativo') ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE65100),
                  side: const BorderSide(color: Color(0xFFE65100)),
                ),
                onPressed: _darBaixa,
                icon: const Icon(Icons.arrow_downward_outlined),
                label: const Text('Dar baixa'),
              ),
            ],
                  ],
        ),
      ),
    );
  }

  Widget _buildFoto(String? path) {
    if (path == null) return _placeholder();
    if (!path.startsWith('http')) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, e, stack) => _placeholder(),
      );
    }
    return CachedNetworkImage(
      imageUrl: path,
      fit: BoxFit.cover,
      placeholder: (_, _) => const ColoredBox(color: Color(0xFFE8F5E9)),
      errorWidget: (_, _, _) => _placeholder(),
    );
  }

  Widget _placeholder() => const ColoredBox(
        color: Color(0xFFE8F5E9),
        child: Icon(Icons.pets, size: 36, color: Color(0xFF2E7D32)),
      );

  void _abrirFotoFullscreen(String path) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar',
      barrierColor: Colors.black87,
      pageBuilder: (ctx, _, _) => SafeArea(
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: path.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: path,
                        fit: BoxFit.contain,
                        placeholder: (_, _) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                        errorWidget: (_, _, _) =>
                            const Icon(Icons.broken_image, color: Colors.white, size: 64),
                      )
                    : Image.file(
                        File(path),
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image, color: Colors.white, size: 64),
                      ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Histórico sanitário ──────────────────────────────────────────────────────

class _HistoricoSanitarioCard extends StatelessWidget {
  final List<EventoSanitarioCompleto> eventos;
  final void Function(int eventoId) onVerEvento;

  const _HistoricoSanitarioCard({
    required this.eventos,
    required this.onVerEvento,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              'HISTÓRICO SANITÁRIO',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          if (eventos.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Nenhum manejo registrado.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            )
          else
            ...eventos.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              final cor = _corPorTipo(e.tipo);
              return Column(
                children: [
                  if (i > 0) const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cor.withValues(alpha: 0.15),
                      child: Icon(_iconePorTipo(e.tipo), color: cor, size: 20),
                    ),
                    title: Text(
                      e.tipo,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      [
                        if (e.dataEvento != null) e.dataEvento!,
                        if (e.produtoUtilizado != null) e.produtoUtilizado!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => onVerEvento(e.id),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

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
}

// ─── Info grid ────────────────────────────────────────────────────────────────

class _InfoItem {
  final String label;
  final String? value;
  const _InfoItem(this.label, this.value);
}

class _InfoGrid extends StatelessWidget {
  final List<_InfoItem> items;
  const _InfoGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    final visible = items.where((i) => i.value != null && i.value!.isNotEmpty).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 24,
      runSpacing: 12,
      children: visible
          .map((i) => SizedBox(
                width: (MediaQuery.of(context).size.width - 80) / 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i.label,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      i.value!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

// ─── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _cores(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status,
        style: TextStyle(
            fontSize: 11, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }

  static (Color, Color) _cores(String s) {
    return switch (s.toLowerCase()) {
      'ativo'        => (const Color(0xFFE8F5E9), const Color(0xFF1B5E20)),
      'em quarentena'=> (const Color(0xFFFFF3E0), const Color(0xFFE65100)),
      'vendido'      => (const Color(0xFFE3F2FD), const Color(0xFF0D47A1)),
      'abatido'      => (const Color(0xFFFFEBEE), const Color(0xFFB71C1C)),
      'inativo'      => (const Color(0xFFEEEEEE), const Color(0xFF424242)),
      _              => (const Color(0xFFEEEEEE), const Color(0xFF424242)),
    };
  }
}

// ─── Vincular terneiro sheet ──────────────────────────────────────────────────

class _VincularTerneiroSheet extends StatefulWidget {
  final Bovino mae;
  final String uid;
  const _VincularTerneiroSheet({required this.mae, required this.uid});

  @override
  State<_VincularTerneiroSheet> createState() => _VincularTerneiroSheetState();
}

class _VincularTerneiroSheetState extends State<_VincularTerneiroSheet> {
  final _brincoCtrl = TextEditingController();
  Bovino? _encontrado;
  bool _buscando = false;
  bool _jaBuscou = false;
  bool _salvando = false;

  @override
  void dispose() {
    _brincoCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final brinco = _brincoCtrl.text.trim();
    if (brinco.isEmpty) return;
    setState(() {
      _buscando = true;
      _jaBuscou = false;
      _encontrado = null;
    });
    final db = await AppDatabase.instance.instanceFor(widget.uid);
    final bovino = await BovinoLocalRepository(db).buscarPorBrincoExato(brinco);
    if (mounted) {
      setState(() {
        _buscando = false;
        _jaBuscou = true;
        _encontrado = bovino;
      });
    }
  }

  Future<void> _salvar() async {
    final brinco = _brincoCtrl.text.trim();
    if (brinco.isEmpty || !_jaBuscou || _salvando) return;
    setState(() => _salvando = true);

    try {
      final uid = widget.uid;
      final mae = widget.mae;
      final db = await AppDatabase.instance.instanceFor(uid);
      final repo = BovinoLocalRepository(db);
      if (!mounted) return;
      final syncSvc = context.read<SyncStatusService>();

      if (_encontrado != null) {
        await repo.vincularTerneiro(_encontrado!.id!, mae.id!);
        if (mounted) {
          final atualizado = _encontrado!.copyWith(idMae: mae.id);
          BovinoRemoteRepository(uid: uid, sync: syncSvc).salvar(atualizado);
        }
      } else {
        if (!mounted) return;
        final criar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Criar terneiro?'),
            content: Text(
              'Nenhum animal com brinco "$brinco" foi encontrado. '
              'Deseja criar esse cadastro e vincular a esta mãe?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Criar e vincular'),
              ),
            ],
          ),
        );
        if (criar != true || !mounted) {
          setState(() => _salvando = false);
          return;
        }
        final terneiro = await repo.criarTerneiroVinculado(
          numeroBrinco: brinco,
          mae: mae,
        );
        if (mounted) {
          BovinoRemoteRepository(uid: uid, sync: syncSvc).salvar(terneiro);
        }
      }

      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Informar terneiro',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Digite o brinco do terneiro desta vaca.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _brincoCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Brinco do terneiro *',
                    hintText: 'Ex: 0042',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _buscar(),
                  onChanged: (_) {
                    if (_jaBuscou) {
                      setState(() {
                        _jaBuscou = false;
                        _encontrado = null;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _buscando ? null : _buscar,
                  child: _buscando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Buscar'),
                ),
              ),
            ],
          ),
          if (_jaBuscou) ...[
            const SizedBox(height: 10),
            if (_encontrado != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: Color(0xFF2E7D32), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        [
                          'Brinco ${_encontrado!.numeroBrinco}',
                          if (_encontrado!.raca != null) _encontrado!.raca!,
                          if (_encontrado!.invernadaDescricao != null)
                            _encontrado!.invernadaDescricao!,
                        ].join(' | '),
                        style: const TextStyle(
                          color: Color(0xFF1B5E20),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_outlined,
                        color: Color(0xFFE65100), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Animal não encontrado — um novo cadastro será criado',
                        style: TextStyle(
                          color: Color(0xFFE65100),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: (_jaBuscou && !_salvando) ? _salvar : null,
            child: _salvando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(_encontrado != null ? 'Vincular' : 'Criar e vincular'),
          ),
        ],
      ),
    );
  }
}

// ─── Dar Baixa sheet ──────────────────────────────────────────────────────────

class _DarBaixaSheet extends StatefulWidget {
  const _DarBaixaSheet();

  @override
  State<_DarBaixaSheet> createState() => _DarBaixaSheetState();
}

class _DarBaixaSheetState extends State<_DarBaixaSheet> {
  static const _motivos = ['Venda', 'Abate', 'Morte', 'Doação', 'Outros'];

  String _motivo = 'Venda';
  DateTime _dataBaixa = DateTime.now();
  final _obsController = TextEditingController();

  @override
  void dispose() {
    _obsController.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _selecionarData() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dataBaixa,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (d != null) setState(() => _dataBaixa = d);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Dar baixa no animal',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _motivo,
            decoration: const InputDecoration(
              labelText: 'Motivo *',
              border: OutlineInputBorder(),
            ),
            items: _motivos
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) => setState(() => _motivo = v!),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _selecionarData,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Data da baixa *',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(_fmt(_dataBaixa)),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _obsController,
            decoration: const InputDecoration(
              labelText: 'Observações',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
            ),
            onPressed: () {
              final obs = _obsController.text.trim();
              Navigator.pop(context, {
                'motivo': _motivo,
                'dataBaixa': _fmt(_dataBaixa),
                'dataBaixaMillis': _dataBaixa.millisecondsSinceEpoch,
                'observacoes': obs.isEmpty ? null : obs,
              });
            },
            child: const Text('Confirmar baixa'),
          ),
        ],
      ),
    );
  }
}
