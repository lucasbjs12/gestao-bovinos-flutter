import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/db/app_database.dart';
import '../../auth/auth_provider.dart';
import '../data/atividade.dart';
import '../data/atividade_local_repository.dart';

class DiarioAtividadesScreen extends StatefulWidget {
  const DiarioAtividadesScreen({super.key});

  @override
  State<DiarioAtividadesScreen> createState() => _DiarioAtividadesScreenState();
}

class _DiarioAtividadesScreenState extends State<DiarioAtividadesScreen> {
  static const _pageSize = 50;

  final List<Atividade> _atividades = [];
  bool _carregando = true;
  bool _temMais = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar({bool mais = false}) async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;

    final db = await AppDatabase.instance.instanceFor(uid);
    final novas = await AtividadeLocalRepository(db).listar(
      limit: _pageSize,
      offset: mais ? _atividades.length : 0,
    );

    if (!mounted) return;
    setState(() {
      if (!mais) _atividades.clear();
      _atividades.addAll(novas);
      _temMais = novas.length == _pageSize;
      _carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diário de atividades')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _atividades.isEmpty
              ? const _EstadoVazio()
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _atividades.length + (_temMais ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _atividades.length) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: OutlinedButton(
                              onPressed: () => _carregar(mais: true),
                              child: const Text('Carregar mais'),
                            ),
                          ),
                        );
                      }
                      final a = _atividades[i];
                      final mostrarData = i == 0 ||
                          !_mesmoDia(_atividades[i - 1].dataMillis, a.dataMillis);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (mostrarData) _CabecalhoData(millis: a.dataMillis),
                          ListTile(
                            leading: Icon(_iconePara(a.acao)),
                            title: Text(a.descricao),
                            subtitle: Text(_hora(a.dataMillis) +
                                (a.autorNome != null ? ' · ${a.autorNome}' : '')),
                            dense: true,
                          ),
                        ],
                      );
                    },
                  ),
                ),
    );
  }

  static bool _mesmoDia(int m1, int m2) {
    final d1 = DateTime.fromMillisecondsSinceEpoch(m1);
    final d2 = DateTime.fromMillisecondsSinceEpoch(m2);
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  static String _hora(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static IconData _iconePara(String acao) {
    if (acao.startsWith('bovino')) return Icons.pets_outlined;
    if (acao.startsWith('evento')) return Icons.medical_services_outlined;
    if (acao.startsWith('invernada')) return Icons.grass_outlined;
    switch (acao) {
      case 'baixa':
        return Icons.arrow_downward;
      case 'reativacao':
        return Icons.restore;
      case 'movimentacao':
        return Icons.swap_horiz;
      default:
        return Icons.history;
    }
  }
}

class _CabecalhoData extends StatelessWidget {
  final int millis;
  const _CabecalhoData({required this.millis});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        _rotulo(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  String _rotulo() {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    final hoje = DateTime.now();
    final ontem = hoje.subtract(const Duration(days: 1));
    if (d.year == hoje.year && d.month == hoje.month && d.day == hoje.day) {
      return 'Hoje';
    }
    if (d.year == ontem.year && d.month == ontem.month && d.day == ontem.day) {
      return 'Ontem';
    }
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

class _EstadoVazio extends StatelessWidget {
  const _EstadoVazio();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history,
              size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text('Nenhuma atividade registrada ainda.'),
          const SizedBox(height: 4),
          Text(
            'As ações feitas no app aparecem aqui automaticamente.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
