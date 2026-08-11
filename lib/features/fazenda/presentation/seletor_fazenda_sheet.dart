import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_provider.dart';
import '../data/fazenda_membros_service.dart';

/// Abre a folha de troca de fazenda. Retorna true se a fazenda ativa mudou.
Future<bool> mostrarSeletorFazenda(BuildContext context) async {
  final mudou = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _SeletorFazendaSheet(),
  );
  return mudou ?? false;
}

class _SeletorFazendaSheet extends StatefulWidget {
  const _SeletorFazendaSheet();

  @override
  State<_SeletorFazendaSheet> createState() => _SeletorFazendaSheetState();
}

class _SeletorFazendaSheetState extends State<_SeletorFazendaSheet> {
  List<({String id, String nome})> _vinculos = [];
  bool _carregando = true;
  bool _processando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final v = await context.read<AuthProvider>().fazendasVinculadas();
    if (mounted) setState(() { _vinculos = v; _carregando = false; });
  }

  Future<void> _trocarPara(String fazendaId, {String? nome}) async {
    setState(() => _processando = true);
    final auth = context.read<AuthProvider>();
    if (fazendaId == auth.currentUser?.uid) {
      await auth.voltarParaMinhaFazenda();
    } else {
      await auth.entrarNaFazenda(fazendaId, nome: nome);
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _entrarComCodigo() async {
    final controller = TextEditingController();
    final codigo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Entrar numa fazenda'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Digite o código de convite que o dono da fazenda '
                'compartilhou com você.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Código',
                hintText: 'BOV-XXXXXX',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Entrar'),
          ),
        ],
      ),
    );

    if (codigo == null || codigo.isEmpty) return;
    setState(() => _processando = true);
    try {
      final r = await FazendaMembrosService.aceitarConvite(codigo);
      if (!mounted) return;
      await context.read<AuthProvider>().entrarNaFazenda(r.fazendaId, nome: r.nome);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _processando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final ativaId = auth.fazendaId;
    final meuUid = auth.currentUser?.uid;
    final meuNome = auth.currentUser?.displayName ?? 'Minha fazenda';
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _processando
            ? const SizedBox(
                height: 160, child: Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Text('Trocar de fazenda',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                  // Própria fazenda (convidado não tem fazenda própria)
                  if (!auth.ehConvidado)
                    _FazendaTile(
                      ativa: ativaId == meuUid,
                      icone: Icons.star,
                      titulo: meuNome,
                      subtitulo: 'Sua fazenda · dono',
                      onTap: ativaId == meuUid ? null : () => _trocarPara(meuUid ?? ''),
                    ),
                  if (_carregando)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  for (final v in _vinculos)
                    _FazendaTile(
                      ativa: ativaId == v.id,
                      icone: Icons.group,
                      titulo: v.nome.isEmpty ? 'Fazenda compartilhada' : v.nome,
                      subtitulo: 'Compartilhada · convidado',
                      onTap: ativaId == v.id
                          ? null
                          : () => _trocarPara(v.id, nome: v.nome),
                    ),
                  const Divider(height: 20),
                  ListTile(
                    leading: Icon(Icons.login, color: cs.primary),
                    title: const Text('Entrar em outra fazenda'),
                    subtitle: const Text('Use um código de convite'),
                    onTap: _entrarComCodigo,
                  ),
                ],
              ),
      ),
    );
  }
}

class _FazendaTile extends StatelessWidget {
  final bool ativa;
  final IconData icone;
  final String titulo;
  final String subtitulo;
  final VoidCallback? onTap;

  const _FazendaTile({
    required this.ativa,
    required this.icone,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(ativa ? Icons.check_circle : icone,
          color: ativa ? cs.primary : cs.onSurfaceVariant),
      title: Text(titulo,
          style: TextStyle(
              fontWeight: ativa ? FontWeight.w600 : FontWeight.w500)),
      subtitle: Text(subtitulo),
      selected: ativa,
      selectedTileColor: cs.primary.withValues(alpha: 0.06),
      onTap: onTap,
    );
  }
}
