import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../auth/auth_provider.dart';
import '../bovinos_provider.dart';
import '../data/bovino.dart';

class BovinosScreen extends StatefulWidget {
  const BovinosScreen({super.key});

  @override
  State<BovinosScreen> createState() => _BovinosScreenState();
}

class _BovinosScreenState extends State<BovinosScreen> {
  final _searchCtrl = TextEditingController();

  // ── Seleção em batch ──────────────────────────────────────────────────────
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

  void _entrarModoSelecao(int id) {
    setState(() {
      _modoSelecao = true;
      _selecionados.add(id);
    });
  }

  void _toggleSelecao(int id) {
    setState(() {
      if (_selecionados.contains(id)) {
        _selecionados.remove(id);
        if (_selecionados.isEmpty) _modoSelecao = false;
      } else {
        _selecionados.add(id);
      }
    });
  }

  void _sairModoSelecao() {
    setState(() {
      _modoSelecao = false;
      _selecionados.clear();
    });
  }

  void _selecionarTodos(List<Bovino> bovinos) {
    setState(() {
      if (_selecionados.length == bovinos.length) {
        _selecionados.clear();
        if (_selecionados.isEmpty) _modoSelecao = false;
      } else {
        _selecionados.addAll(bovinos.map((b) => b.id!));
      }
    });
  }

  Future<void> _abrirCadastro({int? bovinoId}) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.cadastroBovino,
      arguments: bovinoId,
    );
    if (mounted) context.read<BovinosProvider>().recarregar();
  }

  Future<void> _abrirDetalhe(int bovinoId) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.detalheBovino,
      arguments: bovinoId,
    );
    if (mounted) context.read<BovinosProvider>().recarregar();
  }

  Future<void> _criarEventoParaSelecionados() async {
    final ids = _selecionados.toList();
    _sairModoSelecao();
    await Navigator.pushNamed(
      context,
      AppRoutes.cadastroEvento,
      arguments: ids,
    );
    if (mounted) context.read<BovinosProvider>().recarregar();
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
              Text(
                'Registrar baixa para $count animal${count > 1 ? 'is' : ''}?',
              ),
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

    return PopScope(
      canPop: !_modoSelecao,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _sairModoSelecao();
      },
      child: Scaffold(
        appBar: _modoSelecao
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _sairModoSelecao,
                ),
                title: Text('${_selecionados.length} selecionado${_selecionados.length > 1 ? 's' : ''}'),
                actions: [
                  IconButton(
                    icon: Icon(todosSelected
                        ? Icons.deselect
                        : Icons.select_all),
                    tooltip: todosSelected ? 'Desmarcar todos' : 'Selecionar todos',
                    onPressed: () => _selecionarTodos(bovinos),
                  ),
                ],
              )
            : AppBar(
                title: const Text('Bovinos'),
                centerTitle: false,
                actions: [
                  PopupMenuButton<BovinoOrdem>(
                    icon: const Icon(Icons.sort),
                    tooltip: 'Ordenar',
                    initialValue: provider.ordem,
                    onSelected: (o) =>
                        context.read<BovinosProvider>().setOrdem(o),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: BovinoOrdem.brinco,
                        child: Text('Brinco A→Z'),
                      ),
                      PopupMenuItem(
                        value: BovinoOrdem.nome,
                        child: Text('Nome A→Z'),
                      ),
                      PopupMenuItem(
                        value: BovinoOrdem.categoria,
                        child: Text('Categoria'),
                      ),
                      PopupMenuItem(
                        value: BovinoOrdem.invernada,
                        child: Text('Invernada'),
                      ),
                      PopupMenuItem(
                        value: BovinoOrdem.peso,
                        child: Text('Peso (maior primeiro)'),
                      ),
                    ],
                  ),
                ],
              ),
        body: Column(
          children: [
            // Campo de busca (oculto no modo seleção)
            if (!_modoSelecao) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por brinco ou nome…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              context.read<BovinosProvider>().buscar('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                  onChanged: context.read<BovinosProvider>().buscar,
                ),
              ),

              // Filtros de categoria
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _filtros.length,
                  separatorBuilder: (_, i) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final (value, label) = _filtros[i];
                    final isSelected = provider.filtroCategoria == value;
                    return FilterChip(
                      label: Text(label),
                      selected: isSelected,
                      showCheckmark: false,
                      onSelected: (_) =>
                          context.read<BovinosProvider>().setCategoria(value),
                    );
                  },
                ),
              ),
            ],

            // Lista
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : bovinos.isEmpty
                      ? _EmptyState(
                          semFiltro: provider.filtroCategoria == null &&
                              provider.termoBusca.isEmpty,
                        )
                      : RefreshIndicator(
                        onRefresh: () async =>
                            context.read<BovinosProvider>().recarregar(),
                        child: ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                              16, 8, 16, _modoSelecao ? 100 : 88),
                          itemCount: bovinos.length + (provider.temMais ? 1 : 0),
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
                            );
                          },
                        ),
                      ),
            ),
          ],
        ),

        // Barra de ações em batch
        bottomNavigationBar: _modoSelecao && _selecionados.isNotEmpty
            ? _BatchActionBar(
                count: _selecionados.length,
                onEvento: _criarEventoParaSelecionados,
                onBaixa: _confirmarBaixaEmLote,
              )
            : null,

        floatingActionButton: _modoSelecao
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _abrirCadastro(),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar'),
              ),
      ),
    );
  }
}

// ─── Barra de ações em batch ─────────────────────────────────────────────────

class _BatchActionBar extends StatelessWidget {
  final int count;
  final VoidCallback onEvento;
  final VoidCallback onBaixa;

  const _BatchActionBar({
    required this.count,
    required this.onEvento,
    required this.onBaixa,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: onEvento,
              icon: const Icon(Icons.medical_services_outlined, size: 18),
              label: const Text('Criar evento'),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onBaixa,
            icon: Icon(Icons.remove_circle_outline,
                size: 18, color: cs.error),
            label: Text('Baixa', style: TextStyle(color: cs.error)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: cs.error),
            ),
          ),
        ],
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

  const _BovinoCard({
    required this.bovino,
    required this.modoSelecao,
    required this.selecionado,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: selecionado ? cs.primaryContainer.withValues(alpha: 0.4) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selecionado
            ? BorderSide(color: cs.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Checkbox (modo seleção) ou foto
              if (modoSelecao)
                Checkbox(
                  value: selecionado,
                  onChanged: (_) => onTap(),
                  visualDensity: VisualDensity.compact,
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: _buildFoto(bovino.foto),
                  ),
                ),
              const SizedBox(width: 12),

              // Dados
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          bovino.numeroBrinco,
                          style: tt.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (bovino.nomeAnimal != null &&
                            bovino.nomeAnimal!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '· ${bovino.nomeAnimal}',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [bovino.categoria, bovino.raca]
                          .where((s) => s != null && s.isNotEmpty)
                          .join(' · '),
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    if (bovino.invernadaDescricao != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.grass, size: 12, color: cs.primary),
                          const SizedBox(width: 4),
                          Text(
                            bovino.invernadaDescricao!,
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Status chip (oculto no modo seleção para economizar espaço)
              if (!modoSelecao) _StatusBadge(status: bovino.status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFoto(String? path) {
    if (path == null) return _iconePlaceholder();
    if (!path.startsWith('http')) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, e, stack) => _iconePlaceholder(),
      );
    }
    return CachedNetworkImage(
      imageUrl: path,
      fit: BoxFit.cover,
      placeholder: (_, _) => const ColoredBox(color: Color(0xFFE8F5E9)),
      errorWidget: (_, _, _) => _iconePlaceholder(),
    );
  }

  Widget _iconePlaceholder() => const ColoredBox(
        color: Color(0xFFE8F5E9),
        child: Icon(Icons.pets, color: Color(0xFF2E7D32)),
      );
}

// ─── Status badge ────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _cores(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }

  static (Color, Color) _cores(String s) {
    return switch (s.toLowerCase()) {
      'ativo' => (const Color(0xFFE8F5E9), const Color(0xFF1B5E20)),
      'em quarentena' => (const Color(0xFFFFF3E0), const Color(0xFFE65100)),
      'vendido' => (const Color(0xFFE3F2FD), const Color(0xFF0D47A1)),
      'abatido' => (const Color(0xFFFFEBEE), const Color(0xFFB71C1C)),
      _ => (const Color(0xFFEEEEEE), const Color(0xFF424242)),
    };
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.expand_more),
                label: const Text('Carregar mais'),
              ),
      ),
    );
  }
}

// ─── Estado vazio ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool semFiltro;
  const _EmptyState({required this.semFiltro});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pets,
              size: 72, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            semFiltro
                ? 'Nenhum animal cadastrado.\nToque em Adicionar para começar.'
                : 'Nenhum resultado encontrado.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
