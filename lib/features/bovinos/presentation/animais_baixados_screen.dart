import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/db/app_database.dart';
import '../../../core/sync/sync_status_service.dart';
import '../../auth/auth_provider.dart';
import '../../home/home_provider.dart';
import '../bovinos_provider.dart';
import '../data/baixa_bovino.dart';
import '../data/baixa_bovino_remote_repository.dart';
import '../data/bovino_local_repository.dart';

class AnimaisBaixadosScreen extends StatefulWidget {
  const AnimaisBaixadosScreen({super.key});

  @override
  State<AnimaisBaixadosScreen> createState() => _AnimaisBaixadosScreenState();
}

class _AnimaisBaixadosScreenState extends State<AnimaisBaixadosScreen> {
  List<BovinoBaixado> _todos = [];
  bool _carregando = true;
  String? _filtroMotivo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  Future<void> _carregar() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) {
      setState(() => _carregando = false);
      return;
    }
    final db = await AppDatabase.instance.instanceFor(uid);
    final lista = await BovinoLocalRepository(db).listarBaixados();
    if (mounted) setState(() { _todos = lista; _carregando = false; });
  }

  List<BovinoBaixado> get _filtrados => _filtroMotivo == null
      ? _todos
      : _todos.where((b) => b.motivo == _filtroMotivo).toList();

  List<String> get _motivosDisponiveis {
    final motivos = _todos.map((b) => b.motivo).toSet().toList();
    motivos.sort();
    return motivos;
  }

  Future<void> _confirmarReativacao(BovinoBaixado b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reativar animal'),
        content: Text(
          'Deseja reativar ${b.nomeAnimal ?? b.numeroBrinco}? '
          'O animal voltará para a lista de ativos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reativar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;
    final syncSvc = context.read<SyncStatusService>();
    final bovinosProvider = context.read<BovinosProvider>();
    final homeProvider = context.read<HomeProvider>();

    final db = await AppDatabase.instance.instanceFor(uid);
    final bovino = await BovinoLocalRepository(db).reativarBovino(b.id);

    BaixaBovinoRemoteRepository(uid: uid, sync: syncSvc).reativar(bovino);

    bovinosProvider.recarregar();
    homeProvider.carregar(uid);

    if (mounted) _carregar();
  }

  Future<void> _excluirPermanentemente(BovinoBaixado b) async {
    final nome = b.nomeAnimal ?? b.numeroBrinco;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir permanentemente?'),
        content: Text(
          'Isso apagará "$nome" e todo o seu histórico de forma irreversível. '
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

    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;
    final syncSvc = context.read<SyncStatusService>();
    final bovinosProvider = context.read<BovinosProvider>();
    final homeProvider = context.read<HomeProvider>();

    final db = await AppDatabase.instance.instanceFor(uid);
    await db.delete('baixas_bovinos', where: 'id = ?', whereArgs: [b.baixaId]);
    await db.delete('bovinos', where: 'id = ?', whereArgs: [b.id]);

    BaixaBovinoRemoteRepository(uid: uid, sync: syncSvc)
        .excluirPermanente(syncId: b.syncId, bovinoId: b.id);

    bovinosProvider.recarregar();
    homeProvider.carregar(uid);

    if (mounted) _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;
    final motivos = _motivosDisponiveis;

    return Scaffold(
      appBar: AppBar(title: const Text('Animais baixados')),
      body: Column(
        children: [
          // ── Chips de filtro por motivo ────────────────────────────────
          if (!_carregando && motivos.length > 1)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Todos'),
                      selected: _filtroMotivo == null,
                      onSelected: (_) => setState(() => _filtroMotivo = null),
                    ),
                  ),
                  ...motivos.map((m) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(m),
                          selected: _filtroMotivo == m,
                          onSelected: (_) =>
                              setState(() => _filtroMotivo = m),
                        ),
                      )),
                ],
              ),
            ),

          // ── Lista ────────────────────────────────────────────────────
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : filtrados.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Nenhum animal baixado.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _carregar,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                          itemCount: filtrados.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 4),
                          itemBuilder: (ctx, i) {
                            final b = filtrados[i];
                            return Card(
                              child: ListTile(
                                leading: _buildFoto(b.foto),
                                title: Text(b.nomeAnimal ?? b.numeroBrinco),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (b.nomeAnimal != null)
                                      Text(b.numeroBrinco),
                                    Row(
                                      children: [
                                        _MotivoChip(motivo: b.motivo),
                                        if (b.dataBaixa != null) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            b.dataBaixa!,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF6E6E73),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                isThreeLine: b.nomeAnimal != null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: () => _confirmarReativacao(b),
                                      child: const Text('Reativar'),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_forever_outlined),
                                      color: Theme.of(context).colorScheme.error,
                                      tooltip: 'Excluir permanentemente',
                                      onPressed: () => _excluirPermanentemente(b),
                                    ),
                                  ],
                                ),
                              ),
                            );
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

class _MotivoChip extends StatelessWidget {
  final String motivo;
  const _MotivoChip({required this.motivo});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (motivo.toLowerCase()) {
      'venda'  => (const Color(0xFFE3F2FD), const Color(0xFF0D47A1)),
      'abate'  => (const Color(0xFFFFEBEE), const Color(0xFFB71C1C)),
      'morte'  => (const Color(0xFFEEEEEE), const Color(0xFF424242)),
      'doação' => (const Color(0xFFE8F5E9), const Color(0xFF1B5E20)),
      _        => (const Color(0xFFFFF3E0), const Color(0xFFE65100)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        motivo,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
