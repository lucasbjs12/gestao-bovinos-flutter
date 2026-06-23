import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../auth/auth_provider.dart';
import '../data/invernada.dart';
import '../invernadas_provider.dart';

class InvernadasScreen extends StatefulWidget {
  const InvernadasScreen({super.key});

  @override
  State<InvernadasScreen> createState() => _InvernadasScreenState();
}

class _InvernadasScreenState extends State<InvernadasScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  Future<void> _carregar() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid != null && mounted) {
      await context.read<InvernadasProvider>().carregar(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invernadas')),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () async {
          final provider = context.read<InvernadasProvider>();
          await Navigator.pushNamed(context, AppRoutes.cadastroInvernada);
          if (mounted) await provider.recarregar();
        },
        child: const Icon(Icons.add),
      ),
      body: Consumer<InvernadasProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.invernadas.isEmpty) {
            return const _Empty();
          }
          return RefreshIndicator(
            onRefresh: () => context.read<InvernadasProvider>().recarregar(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              itemCount: provider.invernadas.length,
              itemBuilder: (context, i) =>
                  _InvernadaCard(invernada: provider.invernadas[i]),
            ),
          );
        },
      ),
    );
  }
}

// ─── Card ─────────────────────────────────────────────────────────────────────

class _InvernadaCard extends StatelessWidget {
  final Invernada invernada;

  const _InvernadaCard({required this.invernada});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qtd = invernada.quantidadeBovinos;
    final cats = invernada.categoriasBovinos;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.fence_outlined,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          invernada.descricao,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '$qtd ${qtd == 1 ? 'animal' : 'animais'}',
              style: theme.textTheme.bodySmall,
            ),
            if (cats != null && cats.isNotEmpty)
              Text(
                cats,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.pushNamed(
            context,
            AppRoutes.detalheInvernada,
            arguments: invernada.id,
          );
          if (context.mounted) {
            await context.read<InvernadasProvider>().recarregar();
          }
        },
      ),
    );
  }
}

// ─── Empty ────────────────────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.fence_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhuma invernada cadastrada',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text('Toque no + para adicionar'),
        ],
      ),
    );
  }
}
