import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/db/app_database.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/sync/sync_status_service.dart';
import '../../auth/auth_provider.dart';
import '../../bovinos/data/bovino.dart';
import '../../bovinos/data/bovino_remote_repository.dart';
import '../../bovinos/presentation/bovinos_screen.dart';
import '../data/invernada.dart';
import '../data/invernada_local_repository.dart';
import '../data/invernada_remote_repository.dart';
import '../data/movimentacao_invernada.dart';
import '../invernadas_provider.dart';

class DetalheInvernadaScreen extends StatefulWidget {
  const DetalheInvernadaScreen({super.key});

  @override
  State<DetalheInvernadaScreen> createState() => _DetalheInvernadaScreenState();
}

class _DetalheInvernadaScreenState extends State<DetalheInvernadaScreen> {
  Invernada? _invernada;
  List<Bovino> _bovinos = [];
  bool _carregando = true;
  String? _uid;

  bool _modoSelecao = false;
  final Set<int> _selecionados = {};

  final _searchCtrl = TextEditingController();
  String _termoBusca = '';

  List<Bovino> get _bovinosFiltrados {
    if (_termoBusca.isEmpty) return _bovinos;
    final termo = _termoBusca.toLowerCase();
    return _bovinos.where((b) =>
      b.numeroBrinco.toLowerCase().contains(termo) ||
      (b.nomeAnimal?.toLowerCase().contains(termo) ?? false),
    ).toList();
  }

  void _entrarModoSelecao(int id) => setState(() {
        _modoSelecao = true;
        _selecionados.add(id);
      });

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

  void _selecionarTodos() => setState(() {
        if (_selecionados.length == _bovinos.length) {
          _selecionados.clear();
          _modoSelecao = false;
        } else {
          _selecionados.addAll(_bovinos.map((b) => b.id!));
        }
      });

  Future<void> _moverSelecionados() async {
    if (_uid == null || _selecionados.isEmpty) return;

    final titulo =
        'Mover ${_selecionados.length} animal${_selecionados.length > 1 ? 'is' : ''} para';
    final resultado =
        await showModalBottomSheet<({Invernada? invernada, bool confirmou})>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SelecionarInvernadaSheet(
        uid: _uid!,
        titulo: titulo,
        excluirInvernadaId: _invernada?.id,
      ),
    );

    if (resultado == null || !resultado.confirmou || !mounted) return;

    final ids = _selecionados.toList();
    _sairModoSelecao();

    final syncSvc = context.read<SyncStatusService>();
    final invernadasProvider = context.read<InvernadasProvider>();

    final db = await AppDatabase.instance.instanceFor(_uid);
    final atualizados = await InvernadaLocalRepository(db).moverBovinos(
      bovinoIds: ids,
      novaInvernadaId: resultado.invernada?.id,
    );

    final remoto = BovinoRemoteRepository(uid: _uid!, sync: syncSvc);
    for (final b in atualizados) {
      remoto.salvar(b);
    }

    invernadasProvider.recarregar();
    if (mounted) await _carregar();
  }

  Future<void> _removerDaInvernada() async {
    if (_uid == null || _selecionados.isEmpty) return;
    final count = _selecionados.length;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover da invernada?'),
        content: Text(
          '$count animal${count > 1 ? 'is' : ''} '
          'ser${count > 1 ? 'ão' : 'á'} '
          'movido${count > 1 ? 's' : ''} para "Sem invernada".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final ids = _selecionados.toList();
    _sairModoSelecao();

    final syncSvc = context.read<SyncStatusService>();
    final invernadasProvider = context.read<InvernadasProvider>();

    final db = await AppDatabase.instance.instanceFor(_uid);
    final atualizados = await InvernadaLocalRepository(db).moverBovinos(
      bovinoIds: ids,
      novaInvernadaId: null,
    );

    final remoto = BovinoRemoteRepository(uid: _uid!, sync: syncSvc);
    for (final b in atualizados) {
      remoto.salvar(b);
    }

    invernadasProvider.recarregar();
    if (mounted) await _carregar();
  }

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _termoBusca = _searchCtrl.text));
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    _uid = context.read<AuthProvider>().currentUser?.uid;
    final id = ModalRoute.of(context)?.settings.arguments as int?;
    if (id == null || _uid == null) {
      setState(() => _carregando = false);
      return;
    }
    final db = await AppDatabase.instance.instanceFor(_uid);
    final inv = await InvernadaLocalRepository(db).buscarPorId(id);
    final bovinos = await InvernadaLocalRepository(db).listarBovinosDaInvernada(id);
    if (mounted) {
      setState(() {
        _invernada = inv;
        _bovinos = bovinos;
        _carregando = false;
      });
    }
  }

  Future<void> _editar() async {
    await Navigator.pushNamed(
      context,
      AppRoutes.cadastroInvernada,
      arguments: _invernada!.id,
    );
    if (!mounted) return;
    await _carregar();
  }

  Future<void> _confirmarExclusao() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir invernada?'),
        content: Text(
          _bovinos.isEmpty
              ? 'Esta ação não pode ser desfeita.'
              : 'Os ${_bovinos.length} animal(is) desta invernada serão movidos para "Sem invernada". Esta ação não pode ser desfeita.',
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
    if (confirmar != true || !mounted) return;

    final uid = _uid!;
    final invernada = _invernada!;
    final syncSvc = context.read<SyncStatusService>();
    final invernadasProvider = context.read<InvernadasProvider>();

    final db = await AppDatabase.instance.instanceFor(uid);
    final repo = InvernadaLocalRepository(db);

    // Copia bovinos com invernadaId = null ANTES de excluir
    final bovinosSemInvernada = _bovinos
        .map((b) => b.copyWith(clearInvernadaId: true))
        .toList();

    await repo.excluir(invernada.id!);

    // Fire-and-forget: exclui invernada e atualiza bovinos no Firestore
    InvernadaRemoteRepository(uid: uid, sync: syncSvc)
        .excluirComBovinos(invernada.syncId, bovinosSemInvernada);

    invernadasProvider.recarregar();

    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _criarEventoParaInvernada() async {
    if (_bovinos.isEmpty) return;
    final ids = _bovinos.map((b) => b.id!).toList();
    await Navigator.pushNamed(
      context,
      AppRoutes.cadastroEvento,
      arguments: ids,
    );
    if (mounted) await _carregar();
  }

  Future<void> _abrirHistorico() async {
    if (_invernada == null || _uid == null) return;
    final db = await AppDatabase.instance.instanceFor(_uid);
    final historico = await InvernadaLocalRepository(db)
        .listarResumoPorInvernada(_invernada!.id!);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _HistoricoSheet(historico: historico),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_invernada == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Invernada não encontrada.')),
      );
    }

    final todosSelecionados = _bovinos.isNotEmpty &&
        _selecionados.length == _bovinos.length;

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
                title: Text('${_selecionados.length} selecionado${_selecionados.length != 1 ? 's' : ''}'),
                actions: [
                  TextButton(
                    onPressed: _selecionarTodos,
                    child: Text(todosSelecionados ? 'Desmarcar todos' : 'Selecionar todos'),
                  ),
                ],
              )
            : AppBar(
                title: Text(_invernada!.descricao),
                actions: [
                  if (_bovinos.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.checklist_outlined),
                      tooltip: 'Selecionar animais',
                      onPressed: () => _entrarModoSelecao(_bovinos.first.id!),
                    ),
                  if (_bovinos.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.medical_services_outlined),
                      tooltip: 'Criar evento sanitário',
                      onPressed: _criarEventoParaInvernada,
                    ),
                  IconButton(
                    icon: const Icon(Icons.history_outlined),
                    tooltip: 'Histórico',
                    onPressed: _abrirHistorico,
                  ),
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
        bottomNavigationBar: _modoSelecao
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.logout_outlined),
                          label: const Text('Remover'),
                          onPressed: _selecionados.isEmpty ? null : _removerDaInvernada,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.swap_horiz_outlined),
                          label: const Text('Mover'),
                          onPressed: _selecionados.isEmpty ? null : _moverSelecionados,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
        body: RefreshIndicator(
          onRefresh: _carregar,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              if (!_modoSelecao) ...[
                _ResumoCard(invernada: _invernada!),
                const SizedBox(height: 12),
              ],
              if (_bovinos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar por brinco ou nome…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _termoBusca.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => _searchCtrl.clear(),
                            )
                          : null,
                      isDense: true,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  _termoBusca.isEmpty
                      ? 'Animais (${_bovinos.length})'
                      : '${_bovinosFiltrados.length} de ${_bovinos.length} animais',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (_bovinos.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Nenhum animal nesta invernada.')),
                )
              else if (_bovinosFiltrados.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text('Nenhum animal com brinco "$_termoBusca".'),
                  ),
                )
              else
                ..._bovinosFiltrados.map(
                  (b) => _BovinoTile(
                    bovino: b,
                    modoSelecao: _modoSelecao,
                    selecionado: _selecionados.contains(b.id),
                    onTap: _modoSelecao
                        ? () => _toggleSelecao(b.id!)
                        : () async {
                            await Navigator.pushNamed(
                              context,
                              AppRoutes.detalheBovino,
                              arguments: b.id,
                            );
                            if (mounted) await _carregar();
                          },
                    onLongPress: _modoSelecao ? null : () => _entrarModoSelecao(b.id!),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Resumo ───────────────────────────────────────────────────────────────────

class _ResumoCard extends StatelessWidget {
  final Invernada invernada;

  const _ResumoCard({required this.invernada});

  @override
  Widget build(BuildContext context) {
    final qtd = invernada.quantidadeBovinos;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.fence_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    invernada.descricao,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$qtd ${qtd == 1 ? 'animal' : 'animais'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (invernada.categoriasBovinos != null &&
                invernada.categoriasBovinos!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                invernada.categoriasBovinos!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
            if (invernada.observacoes != null &&
                invernada.observacoes!.isNotEmpty) ...[
              const Divider(height: 20),
              Text(
                invernada.observacoes!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Tile de bovino ───────────────────────────────────────────────────────────

class _BovinoTile extends StatelessWidget {
  final Bovino bovino;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool modoSelecao;
  final bool selecionado;

  const _BovinoTile({
    required this.bovino,
    required this.onTap,
    this.onLongPress,
    this.modoSelecao = false,
    this.selecionado = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      color: selecionado
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4)
          : null,
      child: ListTile(
        leading: modoSelecao
            ? Checkbox(
                value: selecionado,
                onChanged: (_) => onTap(),
              )
            : _buildFoto(bovino.foto),
        title: Text(bovino.nomeAnimal ?? bovino.numeroBrinco),
        subtitle: Text(
          [
            if (bovino.nomeAnimal != null) bovino.numeroBrinco,
            if (bovino.categoria != null) bovino.categoria!,
          ].join(' · '),
        ),
        trailing: modoSelecao ? null : const Icon(Icons.chevron_right),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }

  Widget _buildFoto(String? foto) {
    if (foto == null) {
      return const CircleAvatar(child: Icon(Icons.pets_outlined));
    }
    if (foto.startsWith('http')) {
      return CircleAvatar(
        backgroundImage: CachedNetworkImageProvider(foto),
      );
    }
    return CircleAvatar(
      backgroundImage: FileImage(File(foto)),
    );
  }
}

// ─── Histórico ────────────────────────────────────────────────────────────────

class _HistoricoSheet extends StatelessWidget {
  final List<MovimentacaoResumo> historico;

  const _HistoricoSheet({required this.historico});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Histórico de movimentações',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: historico.isEmpty
                ? const Center(child: Text('Nenhuma movimentação registrada.'))
                : ListView.separated(
                    controller: ctrl,
                    itemCount: historico.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => _MovTile(mov: historico[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MovTile extends StatelessWidget {
  final MovimentacaoResumo mov;

  const _MovTile({required this.mov});

  @override
  Widget build(BuildContext context) {
    final de = mov.invernadaAnterior ?? 'Sem invernada';
    final para = mov.novaInvernada ?? 'Sem invernada';

    return ListTile(
      leading: const Icon(Icons.swap_horiz_outlined),
      title: Text(mov.bovinoNome),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$de → $para'),
          Text(
            mov.data,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      isThreeLine: true,
    );
  }
}
