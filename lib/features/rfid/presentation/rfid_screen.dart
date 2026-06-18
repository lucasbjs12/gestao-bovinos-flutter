import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/db/app_database.dart';
import '../../../core/routes/app_routes.dart';
import '../../auth/auth_provider.dart';
import '../data/leitura_rfid.dart';
import '../data/rfid_local_repository.dart';

class RfidScreen extends StatefulWidget {
  const RfidScreen({super.key});

  @override
  State<RfidScreen> createState() => _RfidScreenState();
}

class _RfidScreenState extends State<RfidScreen> {
  List<LeituraRfid> _leituras = [];
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
    final lista = await RfidLocalRepository(db).listarLeituras();
    if (mounted) setState(() { _leituras = lista; _carregando = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RFID'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Atualizar',
            onPressed: _carregar,
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _leituras.isEmpty
              ? _EmptyState()
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: _leituras.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (ctx, i) {
                      final r = _leituras[i];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFF3E5F5),
                            child: Icon(Icons.nfc, color: Color(0xFF7B1FA2)),
                          ),
                          title: Text(r.nomeAnimal ?? r.numeroBrinco ?? 'Animal #${r.bovinoId}'),
                          subtitle: Text(
                            [
                              if (r.nomeAnimal != null && r.numeroBrinco != null)
                                r.numeroBrinco!,
                              if (r.antena != null) 'Antena: ${r.antena}',
                              r.timestamp,
                            ].join(' · '),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.detalheBovino,
                            arguments: r.bovinoId,
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.nfc,
              size: 72,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma leitura RFID',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'As leituras realizadas com o leitor RFID aparecerão aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
