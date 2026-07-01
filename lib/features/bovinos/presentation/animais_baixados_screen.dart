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

enum _Ordem { maisRecente, maisAntigo, brinco }

class AnimaisBaixadosScreen extends StatefulWidget {
  const AnimaisBaixadosScreen({super.key});

  @override
  State<AnimaisBaixadosScreen> createState() => _AnimaisBaixadosScreenState();
}

class _AnimaisBaixadosScreenState extends State<AnimaisBaixadosScreen> {
  List<BovinoBaixado> _todos = [];
  bool _carregando = true;
  String? _filtroMotivo;
  _Ordem _ordem = _Ordem.maisRecente;
  final _buscaCtrl = TextEditingController();
  String _busca = '';

  @override
  void initState() {
    super.initState();
    _buscaCtrl.addListener(() => setState(() => _busca = _buscaCtrl.text.trim().toLowerCase()));
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) { setState(() => _carregando = false); return; }
    final db = await AppDatabase.instance.instanceFor(uid);
    final lista = await BovinoLocalRepository(db).listarBaixados();
    if (mounted) setState(() { _todos = lista; _carregando = false; });
  }

  List<BovinoBaixado> get _filtrados {
    var lista = _todos;

    if (_filtroMotivo != null) {
      lista = lista.where((b) => b.motivo == _filtroMotivo).toList();
    }

    if (_busca.isNotEmpty) {
      lista = lista.where((b) =>
        b.numeroBrinco.toLowerCase().contains(_busca) ||
        (b.nomeAnimal?.toLowerCase().contains(_busca) ?? false),
      ).toList();
    }

    switch (_ordem) {
      case _Ordem.maisRecente:
        lista.sort((a, b) => (b.dataBaixaMillis ?? 0).compareTo(a.dataBaixaMillis ?? 0));
      case _Ordem.maisAntigo:
        lista.sort((a, b) => (a.dataBaixaMillis ?? 0).compareTo(b.dataBaixaMillis ?? 0));
      case _Ordem.brinco:
        lista.sort((a, b) => a.numeroBrinco.compareTo(b.numeroBrinco));
    }

    return lista;
  }

  List<String> get _motivosDisponiveis {
    final m = _todos.map((b) => b.motivo).toSet().toList()..sort();
    return m;
  }

  int _contagemMotivo(String motivo) => _todos.where((b) => b.motivo == motivo).length;

  void _mostrarOrdem() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Ordenar por', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            ..._Ordem.values.map((o) {
              final label = switch (o) {
                _Ordem.maisRecente => 'Mais recente',
                _Ordem.maisAntigo  => 'Mais antigo',
                _Ordem.brinco      => 'Brinco A → Z',
              };
              return ListTile(
                title: Text(label),
                trailing: _ordem == o ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary) : null,
                onTap: () { setState(() => _ordem = o); Navigator.pop(ctx); },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _mostrarAcoes(BovinoBaixado b) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  _buildFoto(b.foto, radius: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.nomeAnimal ?? b.numeroBrinco,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        if (b.nomeAnimal != null)
                          Text(b.numeroBrinco, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                        if (b.categoria != null)
                          Text(b.categoria!, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.refresh_outlined),
              title: const Text('Reativar animal'),
              subtitle: const Text('Volta para a lista de ativos'),
              onTap: () { Navigator.pop(ctx); _confirmarReativacao(b); },
            ),
            ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: Theme.of(ctx).colorScheme.error),
              title: Text('Excluir permanentemente', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              subtitle: const Text('Apaga o animal e todo o histórico'),
              onTap: () { Navigator.pop(ctx); _excluirPermanentemente(b); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reativar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final uid         = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;
    final syncSvc     = context.read<SyncStatusService>();
    final bovinosProv = context.read<BovinosProvider>();
    final homeProv    = context.read<HomeProvider>();

    final db = await AppDatabase.instance.instanceFor(uid);
    final bovino = await BovinoLocalRepository(db).reativarBovino(b.id);
    BaixaBovinoRemoteRepository(uid: uid, sync: syncSvc).reativar(bovino);
    bovinosProv.recarregar();
    homeProv.carregar(uid);
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final uid         = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;
    final syncSvc     = context.read<SyncStatusService>();
    final bovinosProv = context.read<BovinosProvider>();
    final homeProv    = context.read<HomeProvider>();

    final db = await AppDatabase.instance.instanceFor(uid);
    await db.delete('baixas_bovinos', where: 'id = ?', whereArgs: [b.baixaId]);
    await db.delete('bovinos', where: 'id = ?', whereArgs: [b.id]);
    BaixaBovinoRemoteRepository(uid: uid, sync: syncSvc)
        .excluirPermanente(syncId: b.syncId, bovinoId: b.id);
    bovinosProv.recarregar();
    homeProv.carregar(uid);
    if (mounted) _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;
    final motivos   = _motivosDisponiveis;
    final ordemLabel = switch (_ordem) {
      _Ordem.maisRecente => 'Recente',
      _Ordem.maisAntigo  => 'Antigo',
      _Ordem.brinco      => 'Brinco',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Animais baixados'),
        actions: [
          TextButton.icon(
            onPressed: _mostrarOrdem,
            icon: const Icon(Icons.swap_vert, size: 18),
            label: Text(ordemLabel, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Busca ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              controller: _buscaCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por brinco ou nome...',
                prefixIcon: const Icon(Icons.search_outlined),
                suffixIcon: _busca.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _buscaCtrl.clear(),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          // ── Chips de motivo com contagem ────────────────────────────────
          if (!_carregando && motivos.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('Todos ${_todos.length}'),
                      selected: _filtroMotivo == null,
                      onSelected: (_) => setState(() => _filtroMotivo = null),
                    ),
                  ),
                  ...motivos.map((m) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('$m ${_contagemMotivo(m)}'),
                      selected: _filtroMotivo == m,
                      onSelected: (_) => setState(() => _filtroMotivo = m),
                    ),
                  )),
                ],
              ),
            ),

          // ── Contador ───────────────────────────────────────────────────
          if (!_carregando)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
              child: Row(
                children: [
                  Text(
                    '${filtrados.length} '
                    '${filtrados.length == 1 ? 'animal' : 'animais'}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),

          // ── Lista ──────────────────────────────────────────────────────
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : filtrados.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _busca.isNotEmpty || _filtroMotivo != null
                                ? 'Nenhum animal encontrado para este filtro.'
                                : 'Nenhum animal baixado.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _carregar,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                          itemCount: filtrados.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (ctx, i) {
                            final b = filtrados[i];
                            return Card(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _mostrarAcoes(b),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      _buildFoto(b.foto, radius: 24),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              b.nomeAnimal ?? b.numeroBrinco,
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                            ),
                                            if (b.nomeAnimal != null)
                                              Text(b.numeroBrinco,
                                                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                if (b.categoria != null) ...[
                                                  Text(b.categoria!,
                                                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                                  if (b.raca != null)
                                                    Text(' · ${b.raca}',
                                                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          _MotivoChip(motivo: b.motivo),
                                          if (b.dataBaixa != null) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              b.dataBaixa!,
                                              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
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

  Widget _buildFoto(String? foto, {double radius = 22}) {
    if (foto == null) {
      return CircleAvatar(radius: radius, child: const Icon(Icons.pets_outlined));
    }
    if (foto.startsWith('http')) {
      return CircleAvatar(radius: radius, backgroundImage: CachedNetworkImageProvider(foto));
    }
    return CircleAvatar(radius: radius, backgroundImage: FileImage(File(foto)));
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(motivo, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
    );
  }
}
