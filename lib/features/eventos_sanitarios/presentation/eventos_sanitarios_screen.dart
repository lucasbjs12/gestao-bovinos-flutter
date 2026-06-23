import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../auth/auth_provider.dart';
import '../data/evento_sanitario_completo.dart';
import '../eventos_sanitarios_provider.dart';

class EventosSanitariosScreen extends StatefulWidget {
  const EventosSanitariosScreen({super.key});

  @override
  State<EventosSanitariosScreen> createState() =>
      _EventosSanitariosScreenState();
}

class _EventosSanitariosScreenState extends State<EventosSanitariosScreen> {
  final _searchCtrl = TextEditingController();

  static const _tipos = <(String?, String)>[
    (null, 'Todos'),
    ('Vacinação', 'Vacinação'),
    ('Vermifugação', 'Vermifugação'),
    ('Medicação', 'Medicação'),
    ('Castração', 'Castração'),
    ('Banho', 'Banho'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid != null && mounted) {
      await context.read<EventosSanitariosProvider>().carregar(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventosSanitariosProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Sanitário')),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () async {
          await Navigator.pushNamed(context, AppRoutes.cadastroEvento);
          if (mounted) await provider.recarregar();
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Campo de busca
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por tipo, produto, responsável…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          context.read<EventosSanitariosProvider>().buscar('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              onChanged: context.read<EventosSanitariosProvider>().buscar,
            ),
          ),

          // Filtros de tipo
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _tipos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final (value, label) = _tipos[i];
                final isSelected = provider.filtroTipo == value;
                return FilterChip(
                  label: Text(label),
                  selected: isSelected,
                  showCheckmark: false,
                  onSelected: (_) =>
                      context.read<EventosSanitariosProvider>().setTipo(value),
                );
              },
            ),
          ),

          // Lista
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.eventos.isEmpty
                    ? _Empty(
                        semFiltro: provider.filtroTipo == null &&
                            provider.termoBusca.isEmpty,
                      )
                    : RefreshIndicator(
                        onRefresh: () =>
                            context.read<EventosSanitariosProvider>().recarregar(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                          itemCount: provider.eventos.length +
                              (provider.temMais ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i == provider.eventos.length) {
                              return _CarregarMaisButton(
                                isLoading: provider.isLoadingMais,
                                onTap: () => context
                                    .read<EventosSanitariosProvider>()
                                    .carregarMais(),
                              );
                            }
                            return _EventoCard(evento: provider.eventos[i]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Card ─────────────────────────────────────────────────────────────────────

class _EventoCard extends StatelessWidget {
  final EventoSanitarioCompleto evento;

  const _EventoCard({required this.evento});

  @override
  Widget build(BuildContext context) {
    final cor = _corPorTipo(evento.tipo);
    final qtd = evento.quantidadeBovinos;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: cor.withValues(alpha: 0.15),
          child: Icon(_iconePorTipo(evento.tipo), color: cor),
        ),
        title: Text(
          evento.tipo,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            if (evento.dataEvento != null)
              Text(evento.dataEvento!,
                  style: Theme.of(context).textTheme.bodySmall),
            Text(
              '$qtd ${qtd == 1 ? 'animal' : 'animais'}'
              '${evento.invernadaDescricao != null ? ' · ${evento.invernadaDescricao}' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final provider = context.read<EventosSanitariosProvider>();
          await Navigator.pushNamed(
            context,
            AppRoutes.detalheEvento,
            arguments: evento.id,
          );
          if (context.mounted) await provider.recarregar();
        },
      ),
    );
  }
}

// ─── Empty ────────────────────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  final bool semFiltro;
  const _Empty({this.semFiltro = true});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.medical_services_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            semFiltro
                ? 'Nenhum evento registrado'
                : 'Nenhum resultado encontrado.',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (semFiltro) ...[
            const SizedBox(height: 8),
            const Text('Toque no + para adicionar'),
          ],
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

// ─── Helpers ──────────────────────────────────────────────────────────────────

Color _corPorTipo(String tipo) => switch (tipo) {
      'Vacinação'    => const Color(0xFF1565C0),
      'Vermifugação' => const Color(0xFF2E7D32),
      'Medicação'    => const Color(0xFFE65100),
      'Castração'    => const Color(0xFF6A1B9A),
      'Banho'        => const Color(0xFF00838F),
      _              => const Color(0xFF455A64),
    };

IconData _iconePorTipo(String tipo) => switch (tipo) {
      'Vacinação'    => Icons.vaccines_outlined,
      'Vermifugação' => Icons.bug_report_outlined,
      'Medicação'    => Icons.medication_outlined,
      'Castração'    => Icons.content_cut_outlined,
      'Banho'        => Icons.water_drop_outlined,
      _              => Icons.medical_services_outlined,
    };
