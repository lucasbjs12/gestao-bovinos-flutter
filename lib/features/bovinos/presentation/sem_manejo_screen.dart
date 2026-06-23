import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/db/app_database.dart';
import '../../../core/routes/app_routes.dart';
import '../../auth/auth_provider.dart';
import '../data/baixa_bovino.dart';
import '../data/bovino_local_repository.dart';

class SemManejoScreen extends StatefulWidget {
  const SemManejoScreen({super.key});

  @override
  State<SemManejoScreen> createState() => _SemManejoScreenState();
}

class _SemManejoScreenState extends State<SemManejoScreen> {
  List<BovinoResumoManejo> _todos = [];
  bool _carregando = true;
  int _threshold = 30;

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
    final lista = await BovinoLocalRepository(db).listarComUltimoManejo();
    if (mounted) setState(() { _todos = lista; _carregando = false; });
  }

  List<BovinoResumoManejo> get _filtrados {
    final limite = DateTime.now()
        .subtract(Duration(days: _threshold))
        .millisecondsSinceEpoch;
    return _todos
        .where((b) => b.ultimoManejoMillis == null || b.ultimoManejoMillis! < limite)
        .toList();
  }

  Future<void> _criarEventoParaFiltrados() async {
    final ids = _filtrados.map((b) => b.id).toList();
    await Navigator.pushNamed(
      context,
      AppRoutes.cadastroEvento,
      arguments: ids,
    );
    if (mounted) _carregar();
  }

  String _diasLabel(int? millis) {
    if (millis == null) return 'Nunca realizou';
    final dias = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(millis))
        .inDays;
    return 'Há $dias ${dias == 1 ? 'dia' : 'dias'}';
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;
    return Scaffold(
      appBar: AppBar(title: const Text('Sem manejo sanitário')),
      floatingActionButton: filtrados.isNotEmpty
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: _criarEventoParaFiltrados,
              icon: const Icon(Icons.medical_services_outlined),
              label: Text('Criar evento (${filtrados.length})'),
            )
          : null,
      body: Column(
        children: [
          // ── Chips de threshold ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [30, 60, 90].map((dias) {
                final sel = _threshold == dias;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('+$dias dias'),
                    selected: sel,
                    onSelected: (_) => setState(() => _threshold = dias),
                  ),
                );
              }).toList(),
            ),
          ),
          // ── Lista ────────────────────────────────────────────────────────
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : filtrados.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Todos os animais foram manejados nos últimos $_threshold dias.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _carregar,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          itemCount: filtrados.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 4),
                          itemBuilder: (ctx, i) {
                            final b = filtrados[i];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFFFF3E0),
                                  child: const Icon(
                                    Icons.medical_services_outlined,
                                    color: Color(0xFFE65100),
                                  ),
                                ),
                                title: Text(b.nomeAnimal ?? b.numeroBrinco),
                                subtitle: Text(
                                  [
                                    if (b.nomeAnimal != null) b.numeroBrinco,
                                    if (b.categoria != null) b.categoria!,
                                    if (b.invernadaDescricao != null)
                                      b.invernadaDescricao!,
                                  ].join(' · '),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _diasLabel(b.ultimoManejoMillis),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFE65100),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () async {
                                  await Navigator.pushNamed(
                                    context,
                                    AppRoutes.detalheBovino,
                                    arguments: b.id,
                                  );
                                  if (mounted) _carregar();
                                },
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
}
