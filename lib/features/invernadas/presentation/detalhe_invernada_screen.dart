import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/db/app_database.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/sync/sync_status_service.dart';
import '../../auth/auth_provider.dart';
import '../../bovinos/data/bovino.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_invernada!.descricao),
        actions: [
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
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            // ── Resumo ────────────────────────────────────────────────────
            _ResumoCard(invernada: _invernada!),
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
                child: Center(child: Text('Nenhum animal nesta invernada.')),
              )
            else
              ..._bovinos.map(
                (b) => _BovinoTile(
                  bovino: b,
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
          ],
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

  const _BovinoTile({required this.bovino, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: _buildFoto(bovino.foto),
        title: Text(bovino.nomeAnimal ?? bovino.numeroBrinco),
        subtitle: Text(
          [
            if (bovino.nomeAnimal != null) bovino.numeroBrinco,
            if (bovino.categoria != null) bovino.categoria!,
          ].join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
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
