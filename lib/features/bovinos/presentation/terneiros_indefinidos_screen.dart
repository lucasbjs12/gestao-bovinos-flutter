import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/db/app_database.dart';
import '../../../core/routes/app_routes.dart';
import '../../auth/auth_provider.dart';
import '../data/bovino.dart';
import '../data/bovino_local_repository.dart';

class TerneirosIndefinidosScreen extends StatefulWidget {
  const TerneirosIndefinidosScreen({super.key});

  @override
  State<TerneirosIndefinidosScreen> createState() =>
      _TerneirosIndefinidosScreenState();
}

class _TerneirosIndefinidosScreenState
    extends State<TerneirosIndefinidosScreen> {
  List<Bovino> _lista = [];
  bool _carregando = true;

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
    final lista =
        await BovinoLocalRepository(db).listarTerneirosIndefinidos();
    if (mounted) setState(() { _lista = lista; _carregando = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terneiros indefinidos'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Animais com categoria "Terneiro(a)" sem sexo definido',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _lista.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Nenhum terneiro com categoria indefinida.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: _lista.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (ctx, i) {
                      final b = _lista[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFF3E5F5),
                            child: const Icon(
                              Icons.pets,
                              color: Color(0xFF7B1FA2),
                            ),
                          ),
                          title: Text(b.nomeAnimal ?? b.numeroBrinco),
                          subtitle: Text(
                            [
                              if (b.nomeAnimal != null) b.numeroBrinco,
                              if (b.invernadaDescricao != null)
                                b.invernadaDescricao!,
                            ].join(' · '),
                          ),
                          trailing: const Icon(Icons.edit_outlined),
                          onTap: () async {
                            await Navigator.pushNamed(
                              context,
                              AppRoutes.cadastroBovino,
                              arguments: b.id,
                            );
                            if (mounted) _carregar();
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
