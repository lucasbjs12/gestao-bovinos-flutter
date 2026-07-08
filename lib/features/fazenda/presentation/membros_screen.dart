import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../auth/auth_provider.dart';
import '../data/fazenda_membros_service.dart';
import '../data/membro.dart';

class MembrosScreen extends StatefulWidget {
  const MembrosScreen({super.key});

  @override
  State<MembrosScreen> createState() => _MembrosScreenState();
}

class _MembrosScreenState extends State<MembrosScreen> {
  List<Membro> _membros = [];
  bool _carregando = true;

  String? get _fazendaId => context.read<AuthProvider>().currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final id = _fazendaId;
    if (id == null) return;
    setState(() => _carregando = true);
    try {
      final lista = await FazendaMembrosService.listarMembros(id);
      if (mounted) setState(() => _membros = lista);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _gerarConvite() async {
    final id = _fazendaId;
    if (id == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final codigo = await FazendaMembrosService.gerarConvite(id);
      if (!mounted) return;
      Navigator.pop(context); // fecha loading
      _mostrarCodigo(codigo);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _mostrarCodigo(String codigo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convite gerado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Envie este código ao capataz. Ele vale por '
                '${FazendaMembrosService.conviteValidadeHoras} horas e só '
                'pode ser usado uma vez.'),
            const SizedBox(height: 16),
            SelectableText(
              codigo,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: codigo));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Código copiado.')),
                );
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copiar'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
          FilledButton.icon(
            onPressed: () {
              Share.share(
                'Você foi convidado para gerenciar a fazenda no app Gestão '
                'de Rebanho. Baixe o app, crie sua conta e use o código: '
                '$codigo',
              );
            },
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Compartilhar'),
          ),
        ],
      ),
    ).then((_) => _carregar());
  }

  Future<void> _removerMembro(Membro m) async {
    final id = _fazendaId;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover membro'),
        content: Text('Remover ${m.nome ?? 'este membro'} da fazenda? '
            'Ele perde o acesso aos dados imediatamente.'),
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
    if (ok != true) return;
    await FazendaMembrosService.removerMembro(id, m.uid);
    await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Membros da fazenda')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _gerarConvite,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Convidar capataz'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregar,
              child: ListView(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'O dono tem acesso total. O capataz registra o manejo do '
                      'dia a dia, mas não pode excluir animais nem gerenciar '
                      'membros. Tudo o que ele faz aparece no diário de '
                      'atividades.',
                    ),
                  ),
                  for (final m in _membros)
                    ListTile(
                      leading: CircleAvatar(
                        child: Icon(m.ehDono ? Icons.star : Icons.person),
                      ),
                      title: Text(m.nome ?? m.uid),
                      subtitle: Text(m.ehDono ? 'Dono' : 'Capataz'),
                      trailing: m.ehDono
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              tooltip: 'Remover',
                              onPressed: () => _removerMembro(m),
                            ),
                    ),
                ],
              ),
            ),
    );
  }
}
