import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/db/app_database.dart';
import '../../../core/widgets/marca_painter.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/sync/sync_status_service.dart';
import '../../auth/auth_provider.dart';
import '../../invernadas/data/invernada.dart';
import '../../invernadas/data/invernada_local_repository.dart';
import '../bovinos_provider.dart';
import '../data/bovino.dart';
import '../data/bovino_remote_repository.dart';

class BovinosScreen extends StatefulWidget {
  const BovinosScreen({super.key});

  @override
  State<BovinosScreen> createState() => _BovinosScreenState();
}

class _BovinosScreenState extends State<BovinosScreen> {
  final _searchCtrl = TextEditingController();

  bool _modoSelecao = false;
  final Set<int> _selecionados = {};

  static const _filtros = <(String?, String)>[
    (null, 'Todos'),
    ('Vaca', 'Vaca'),
    ('Novilha', 'Novilha'),
    ('Novilho', 'Novilho'),
    ('Terneiro', 'Terneiro'),
    ('Terneira', 'Terneira'),
    ('Touro', 'Touro'),
    ('Boi', 'Boi'),
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  void _carregar() {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid != null) context.read<BovinosProvider>().carregar(uid);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _entrarModoSelecao(int id) => setState(() {
        _modoSelecao = true;
        _selecionados.add(id);
      });

  void _ativarSelecao() => setState(() => _modoSelecao = true);

  void _toggleSelecao(int id) => setState(() {
        if (_selecionados.contains(id)) {
          _selecionados.remove(id);
          if (_selecionados.isEmpty) _modoSelecao = false;
        } else {
          _selecionados.add(id);
        }
      });

  void _sairModoSelecao() => setState(() {
        _modoSelecao = false;
        _selecionados.clear();
      });

  void _selecionarTodos(List<Bovino> bovinos) => setState(() {
        if (_selecionados.length == bovinos.length) {
          _selecionados.clear();
          _modoSelecao = false;
        } else {
          _selecionados.addAll(bovinos.map((b) => b.id!));
        }
      });

  Future<void> _abrirCadastro({int? bovinoId}) async {
    await Navigator.pushNamed(context, AppRoutes.cadastroBovino,
        arguments: bovinoId);
    if (mounted) context.read<BovinosProvider>().recarregar();
  }

  void _mostrarOpcoesCadastro() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Cadastro individual'),
              subtitle: const Text('Adicionar um animal por vez'),
              onTap: () {
                Navigator.pop(ctx);
                _abrirCadastro();
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_outlined),
              title: const Text('Cadastro em lote'),
              subtitle: const Text('Adicionar vários animais de uma vez'),
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.pushNamed(context, AppRoutes.cadastroLote);
                if (mounted) context.read<BovinosProvider>().recarregar();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirDetalhe(int bovinoId) async {
    await Navigator.pushNamed(context, AppRoutes.detalheBovino,
        arguments: bovinoId);
    if (mounted) context.read<BovinosProvider>().recarregar();
  }

  Future<void> _abrirEventoRapido(int bovinoId) async {
    await Navigator.pushNamed(context, AppRoutes.cadastroEvento,
        arguments: [bovinoId]);
    if (mounted) context.read<BovinosProvider>().recarregar();
  }

  Future<void> _criarEventoParaSelecionados() async {
    final ids = _selecionados.toList();
    _sairModoSelecao();
    await Navigator.pushNamed(context, AppRoutes.cadastroEvento,
        arguments: ids);
    if (mounted) context.read<BovinosProvider>().recarregar();
  }

  Future<void> _moverInvernadaSelecionados() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;

    final resultado = await showModalBottomSheet<({Invernada? invernada, bool confirmou})>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SelecionarInvernadaSheet(
        uid: uid,
        titulo: 'Mover ${_selecionados.length} animal${_selecionados.length > 1 ? 'is' : ''} para',
      ),
    );

    if (resultado == null || !resultado.confirmou || !mounted) return;

    final ids = _selecionados.toList();
    _sairModoSelecao();

    final provider = context.read<BovinosProvider>();
    final syncSvc = context.read<SyncStatusService>();
    final bovinosAtualizados = await provider.moverParaInvernada(
      ids, resultado.invernada?.id);

    // Fire-and-forget sync para Firestore
    final remoto = BovinoRemoteRepository(uid: uid, sync: syncSvc);
    for (final b in bovinosAtualizados) {
      remoto.salvar(b);
    }

    if (mounted) provider.recarregar();
  }

  Future<void> _confirmarBaixaEmLote() async {
    final count = _selecionados.length;
    String motivoSelecionado = 'Vendido';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Baixa em lote'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Registrar baixa para $count animal${count > 1 ? 'is' : ''}?'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: motivoSelecionado,
                decoration: const InputDecoration(
                  labelText: 'Motivo',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'Vendido', child: Text('Vendido')),
                  DropdownMenuItem(value: 'Abatido', child: Text('Abatido')),
                  DropdownMenuItem(value: 'Morte', child: Text('Morte')),
                  DropdownMenuItem(value: 'Outro', child: Text('Outro')),
                ],
                onChanged: (v) =>
                    setDlgState(() => motivoSelecionado = v ?? motivoSelecionado),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
    if (confirm != true || !mounted) return;

    final provider = context.read<BovinosProvider>();
    final hoje = DateTime.now();
    for (final id in _selecionados.toList()) {
      await provider.darBaixa(id, motivo: motivoSelecionado, data: hoje);
    }
    _sairModoSelecao();
    if (mounted) provider.recarregar();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BovinosProvider>();
    final bovinos = provider.bovinos;
    final todosSelected =
        _modoSelecao && bovinos.isNotEmpty && _selecionados.length == bovinos.length;
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_modoSelecao,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _sairModoSelecao();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7F5),
        appBar: _modoSelecao
            ? AppBar(
                backgroundColor: cs.primaryContainer,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _sairModoSelecao,
                ),
                title: Text(
                  '${_selecionados.length} selecionado${_selecionados.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(todosSelected ? Icons.deselect : Icons.select_all),
                    tooltip: todosSelected ? 'Desmarcar todos' : 'Selecionar todos',
                    onPressed: () => _selecionarTodos(bovinos),
                  ),
                ],
              )
            : AppBar(
                backgroundColor: const Color(0xFFF5F7F5),
                scrolledUnderElevation: 0,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bovinos',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    if (!provider.isLoading)
                      Text(
                        '${provider.bovinos.length} animal${provider.bovinos.length != 1 ? 'is' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                  ],
                ),
                actions: [
                  if (bovinos.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.checklist_outlined),
                      tooltip: 'Selecionar animais',
                      onPressed: _ativarSelecao,
                    ),
                  PopupMenuButton<BovinoOrdem>(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.swap_vert_rounded, size: 20, color: cs.onSurface),
                    ),
                    tooltip: 'Ordenar',
                    initialValue: provider.ordem,
                    onSelected: (o) => context.read<BovinosProvider>().setOrdem(o),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: BovinoOrdem.brinco, child: Text('Brinco (crescente)')),
                      PopupMenuItem(value: BovinoOrdem.nome, child: Text('Nome A→Z')),
                      PopupMenuItem(value: BovinoOrdem.categoria, child: Text('Categoria')),
                      PopupMenuItem(value: BovinoOrdem.invernada, child: Text('Invernada')),
                      PopupMenuItem(value: BovinoOrdem.peso, child: Text('Peso (maior primeiro)')),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
              ),
        body: Column(
          children: [
            // ── Barra de busca ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por brinco ou nome…',
                    hintStyle: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: cs.onSurfaceVariant),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchCtrl.clear();
                              context.read<BovinosProvider>().buscar('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: context.read<BovinosProvider>().buscar,
                ),
              ),
            ),

            if (!_modoSelecao) ...[
              // ── Chips de categoria ────────────────────────────────────
              SizedBox(
                height: 50,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  itemCount: _filtros.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (ctx, i) {
                    final (value, label) = _filtros[i];
                    final isSelected = provider.filtroCategoria == value;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      child: FilterChip(
                        label: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        showCheckmark: false,
                        selectedColor: const Color(0xFF2E7D32),
                        labelStyle: isSelected
                            ? const TextStyle(color: Colors.white)
                            : null,
                        onSelected: (_) =>
                            context.read<BovinosProvider>().setCategoria(value),
                      ),
                    );
                  },
                ),
              ),
            ],

            // ── Lista ─────────────────────────────────────────────────
            Expanded(
              child: provider.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF2E7D32),
                      ),
                    )
                  : bovinos.isEmpty
                      ? _EmptyState(
                          semFiltro: provider.filtroCategoria == null &&
                              provider.termoBusca.isEmpty,
                          onAdicionar: () => _abrirCadastro(),
                        )
                      : RefreshIndicator(
                          color: const Color(0xFF2E7D32),
                          onRefresh: () async =>
                              context.read<BovinosProvider>().recarregar(),
                          child: ListView.builder(
                            padding: EdgeInsets.fromLTRB(
                                16, 8, 16, _modoSelecao ? 100 : 100),
                            itemCount:
                                bovinos.length + (provider.temMais ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i == bovinos.length) {
                                return _CarregarMaisButton(
                                  isLoading: provider.isLoadingMais,
                                  onTap: () =>
                                      context.read<BovinosProvider>().carregarMais(),
                                );
                              }
                              final b = bovinos[i];
                              return _BovinoCard(
                                bovino: b,
                                modoSelecao: _modoSelecao,
                                selecionado: _selecionados.contains(b.id),
                                onTap: _modoSelecao
                                    ? () => _toggleSelecao(b.id!)
                                    : () => _abrirDetalhe(b.id!),
                                onLongPress: _modoSelecao
                                    ? null
                                    : () => _entrarModoSelecao(b.id!),
                                onEvento: _modoSelecao
                                    ? null
                                    : () => _abrirEventoRapido(b.id!),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),

        bottomNavigationBar: _modoSelecao && _selecionados.isNotEmpty
            ? _BatchActionBar(
                count: _selecionados.length,
                onEvento: _criarEventoParaSelecionados,
                onMover: _moverInvernadaSelecionados,
                onBaixa: _confirmarBaixaEmLote,
              )
            : null,

        floatingActionButton: _modoSelecao
            ? null
            : FloatingActionButton.extended(
                heroTag: null,
                onPressed: _mostrarOpcoesCadastro,
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Adicionar',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
      ),
    );
  }
}

// ─── Card de bovino ──────────────────────────────────────────────────────────

class _BovinoCard extends StatelessWidget {
  final Bovino bovino;
  final bool modoSelecao;
  final bool selecionado;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEvento;

  const _BovinoCard({
    required this.bovino,
    required this.modoSelecao,
    required this.selecionado,
    required this.onTap,
    this.onLongPress,
    this.onEvento,
  });

  // Returns null (never), or days since last manejo
  int? get _diasSemManejo {
    final m = bovino.ultimoManejoMillis;
    if (m == null) return null;
    return DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(m))
        .inDays;
  }

  // null = ok, 1 = atenção (>30d), 2 = crítico (>90d ou nunca)
  int get _alertaNivel {
    final dias = _diasSemManejo;
    if (dias == null) return 2;
    if (dias > 90) return 2;
    if (dias > 30) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _categoriaColor(bovino.categoria);
    final alerta = selecionado ? 0 : _alertaNivel;

    // Só destaca visualmente (borda + fundo) em nível crítico (>90d ou nunca)
    // Nível 1 (30–90d) apenas exibe o badge de texto, sem alterar o card
    final bgColor = alerta == 2
        ? const Color(0xFFFFF5F5)
        : selecionado
            ? const Color(0xFFE8F5E9)
            : Colors.white;

    final borderColor = alerta == 2 && !selecionado
        ? const Color(0xFFEF4444)
        : selecionado
            ? const Color(0xFF2E7D32)
            : const Color(0x0F000000);

    final borderWidth = (alerta == 2 || selecionado) ? 1.5 : 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: selecionado
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // ── Foto ou checkbox ─────────────────────────────────
                if (modoSelecao)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Checkbox(
                      value: selecionado,
                      onChanged: (_) => onTap(),
                      activeColor: const Color(0xFF2E7D32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  )
                else
                  Stack(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: bovino.foto != null
                              ? accentColor.withValues(alpha: 0.12)
                              : const Color(0xFFEEEEEE),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildFoto(bovino.foto, accentColor),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(width: 12),

                // ── Dados ────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nome (principal) ou brinco se sem nome
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              bovino.nomeAnimal != null &&
                                      bovino.nomeAnimal!.isNotEmpty
                                  ? bovino.nomeAnimal!
                                  : bovino.numeroBrinco,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1C1A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!modoSelecao) ...[
                            const SizedBox(width: 6),
                            _StatusBadge(status: bovino.status),
                          ],
                        ],
                      ),

                      const SizedBox(height: 3),

                      // Brinco (se tem nome) + categoria + raça
                      Text(
                        _subtitulo(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),

                      if (bovino.invernadaDescricao != null ||
                          bovino.pesoAtualKg != null) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            if (bovino.invernadaDescricao != null) ...[
                              const Icon(Icons.grass_rounded,
                                  size: 12, color: Color(0xFF2E7D32)),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  bovino.invernadaDescricao!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF2E7D32),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            if (bovino.invernadaDescricao != null &&
                                bovino.pesoAtualKg != null)
                              const Text(
                                '  ·  ',
                                style: TextStyle(
                                    color: Color(0xFF9CA3AF), fontSize: 12),
                              ),
                            if (bovino.pesoAtualKg != null)
                              Text(
                                '${bovino.pesoAtualKg!.toStringAsFixed(0)} kg',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ],

                      // ── Alerta sem manejo ──────────────────────────
                      if (!modoSelecao && alerta > 0) ...[
                        const SizedBox(height: 5),
                        _AlertaManejoBadge(
                          dias: _diasSemManejo,
                          critico: alerta == 2,
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Ação rápida ──────────────────────────────────────
                if (!modoSelecao)
                  IconButton(
                    icon: const Icon(
                      Icons.medical_services_outlined,
                      size: 20,
                      color: Color(0xFF2E7D32),
                    ),
                    tooltip: 'Registrar manejo',
                    onPressed: onEvento,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitulo() {
    final partes = <String>[];
    if (bovino.nomeAnimal != null && bovino.nomeAnimal!.isNotEmpty) {
      partes.add('# ${bovino.numeroBrinco}');
    }
    if (bovino.categoria != null && bovino.categoria!.isNotEmpty) {
      partes.add(bovino.categoria!);
    }
    if (bovino.raca != null && bovino.raca!.isNotEmpty) {
      partes.add(bovino.raca!);
    }
    return partes.join(' · ');
  }

  Widget _buildFoto(String? path, Color accent) {
    if (path == null) return _placeholder(accent);
    if (!path.startsWith('http')) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(accent),
      );
    }
    return CachedNetworkImage(
      imageUrl: path,
      fit: BoxFit.cover,
      placeholder: (_, _) => _placeholder(accent),
      errorWidget: (_, _, _) => _placeholder(accent),
    );
  }

  Widget _placeholder(Color accent) => const Center(
        child: CustomPaint(
          size: Size(36, 36),
          painter: MarcaPainter(Color(0xFFB0BEB0)),
        ),
      );

  static Color _categoriaColor(String? cat) {
    return switch (cat?.toLowerCase()) {
      'vaca'          => const Color(0xFF7B3F00),
      'novilha'       => const Color(0xFF8B5CF6),
      'novilho'       => const Color(0xFF3B82F6),
      'terneiro'      => const Color(0xFFF59E0B),
      'terneira'      => const Color(0xFFEC4899),
      'terneiro(a)'   => const Color(0xFFF59E0B),
      'touro'         => const Color(0xFFEF4444),
      'boi'           => const Color(0xFF059669),
      _               => const Color(0xFF6B7280),
    };
  }

}

// ─── Alerta sem manejo ───────────────────────────────────────────────────────

class _AlertaManejoBadge extends StatelessWidget {
  final int? dias;
  final bool critico;

  const _AlertaManejoBadge({required this.dias, required this.critico});

  @override
  Widget build(BuildContext context) {
    final color = critico ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF);
    final bg = critico ? const Color(0xFFFFEEEE) : const Color(0xFFF3F4F6);
    final label = dias == null
        ? 'Nunca realizou manejo'
        : 'Sem manejo há $dias dia${dias == 1 ? '' : 's'}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          critico ? Icons.warning_amber_rounded : Icons.info_outline,
          size: 11,
          color: color,
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Status badge ────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _cores(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          color: fg,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  static (Color, Color) _cores(String s) {
    return switch (s.toLowerCase()) {
      'ativo'         => (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      'em quarentena' => (const Color(0xFFFEF3C7), const Color(0xFFB45309)),
      'vendido'       => (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8)),
      'abatido'       => (const Color(0xFFFFE4E6), const Color(0xFFBE123C)),
      _               => (const Color(0xFFF3F4F6), const Color(0xFF374151)),
    };
  }
}

// ─── Barra de ações em batch ─────────────────────────────────────────────────

class _BatchActionBar extends StatelessWidget {
  final int count;
  final VoidCallback onEvento;
  final VoidCallback onMover;
  final VoidCallback onBaixa;

  const _BatchActionBar({
    required this.count,
    required this.onEvento,
    required this.onMover,
    required this.onBaixa,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: onEvento,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.medical_services_outlined, size: 18),
              label: const Text(
                'Criar evento',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onMover,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1565C0),
              side: const BorderSide(color: Color(0xFF1565C0)),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: const Text('Mover',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onBaixa,
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.error,
              side: BorderSide(color: cs.error.withValues(alpha: 0.6)),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: Icon(Icons.arrow_downward_rounded, size: 18, color: cs.error),
            label: Text('Baixa',
                style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─── Botão carregar mais ─────────────────────────────────────────────────────

class _CarregarMaisButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _CarregarMaisButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF2E7D32)),
              )
            : OutlinedButton.icon(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.expand_more_rounded, size: 18),
                label: const Text('Carregar mais'),
              ),
      ),
    );
  }
}

// ─── Estado vazio ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool semFiltro;
  final VoidCallback onAdicionar;

  const _EmptyState({required this.semFiltro, required this.onAdicionar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.pets_rounded,
                size: 52,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              semFiltro ? 'Nenhum animal cadastrado' : 'Nenhum resultado',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1C1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              semFiltro
                  ? 'Cadastre seu primeiro animal para começar a gerenciar o rebanho.'
                  : 'Tente ajustar os filtros ou o termo de busca.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
            if (semFiltro) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAdicionar,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Adicionar animal',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Sheet: selecionar invernada ─────────────────────────────────────────────

class SelecionarInvernadaSheet extends StatefulWidget {
  final String uid;
  final String titulo;
  final int? excluirInvernadaId;

  const SelecionarInvernadaSheet({
    super.key,
    required this.uid,
    required this.titulo,
    this.excluirInvernadaId,
  });

  @override
  State<SelecionarInvernadaSheet> createState() =>
      SelecionarInvernadaSheetState();
}

class SelecionarInvernadaSheetState
    extends State<SelecionarInvernadaSheet> {
  List<Invernada> _invernadas = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final db = await AppDatabase.instance.instanceFor(widget.uid);
    final todas = await InvernadaLocalRepository(db).listar();
    if (mounted) {
      setState(() {
        _invernadas = todas
            .where((i) => i.id != widget.excluirInvernadaId)
            .toList();
        _carregando = false;
      });
    }
  }

  void _selecionar(Invernada? invernada) =>
      Navigator.pop(context, (invernada: invernada, confirmou: true));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              widget.titulo,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(height: 1),
          if (_carregando)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  // Invernadas disponíveis
                  ..._invernadas.map((inv) => ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.fence_outlined,
                              color: Color(0xFF1565C0), size: 20),
                        ),
                        title: Text(
                          inv.descricao,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${inv.quantidadeBovinos} animal${inv.quantidadeBovinos != 1 ? 'is' : ''}',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded,
                            size: 18),
                        onTap: () => _selecionar(inv),
                      )),
                  // Opção "Sem invernada"
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.not_interested_rounded,
                          color: Color(0xFF6B7280), size: 20),
                    ),
                    title: const Text(
                      'Sem invernada',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Remove o animal de qualquer invernada',
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                    onTap: () => _selecionar(null),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
