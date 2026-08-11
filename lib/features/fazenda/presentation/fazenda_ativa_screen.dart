import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_provider.dart';
import '../data/fazenda_membros_service.dart';

/// Troca de fazenda: lista a própria fazenda e as fazendas de donos que
/// convidaram este usuário. Código só é necessário para entrar numa fazenda
/// nova; depois disso a troca é direta.
class FazendaAtivaScreen extends StatefulWidget {
  const FazendaAtivaScreen({super.key});

  @override
  State<FazendaAtivaScreen> createState() => _FazendaAtivaScreenState();
}

class _FazendaAtivaScreenState extends State<FazendaAtivaScreen> {
  bool _processando = false;
  List<({String id, String nome})> _vinculos = [];

  @override
  void initState() {
    super.initState();
    _carregarVinculos();
  }

  Future<void> _carregarVinculos() async {
    final v = await context.read<AuthProvider>().fazendasVinculadas();
    if (mounted) setState(() => _vinculos = v);
  }

  Future<void> _trocarPara(String fazendaId, {String? nome}) async {
    setState(() => _processando = true);
    await context.read<AuthProvider>().entrarNaFazenda(fazendaId, nome: nome);
    if (!mounted) return;
    setState(() => _processando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fazenda alterada.')),
    );
    Navigator.pop(context);
  }

  Future<void> _voltarParaMinha() async {
    setState(() => _processando = true);
    await context.read<AuthProvider>().voltarParaMinhaFazenda();
    if (!mounted) return;
    setState(() => _processando = false);
    Navigator.pop(context);
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você entrou na fazenda.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _processando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _removerVinculo(({String id, String nome}) v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover fazenda'),
        content: Text('Remover "${v.nome.isEmpty ? v.id : v.nome}" da sua '
            'lista? Você precisará de um novo código para entrar de novo.'),
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
    if (ok != true || !mounted) return;
    await context.read<AuthProvider>().removerVinculo(v.id);
    await _carregarVinculos();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final ativaId = auth.fazendaId;
    final meuUid = auth.fazendaPropriaId;
    final meuNome = auth.currentUser?.displayName ?? 'Minha fazenda';

    return Scaffold(
      appBar: AppBar(title: const Text('Fazenda ativa')),
      body: _processando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('Toque para trocar a fazenda que você está '
                      'visualizando.'),
                ),
                // Minha própria fazenda (o backend sempre cria uma no registro,
                // mesmo pra quem entrou como convidado em outra).
                if (meuUid != null)
                  ListTile(
                    leading: Icon(
                      ativaId == meuUid ? Icons.check_circle : Icons.star_outline,
                      color: ativaId == meuUid
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(meuNome),
                    subtitle: const Text('Sua fazenda (dono)'),
                    selected: ativaId == meuUid,
                    onTap: ativaId == meuUid ? null : _voltarParaMinha,
                  ),
                // Fazendas de outros donos
                for (final v in _vinculos)
                  ListTile(
                    leading: Icon(
                      ativaId == v.id ? Icons.check_circle : Icons.group_outlined,
                      color: ativaId == v.id
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title:
                        Text(v.nome.isEmpty ? 'Fazenda compartilhada' : v.nome),
                    subtitle: const Text('Você é convidado'),
                    selected: ativaId == v.id,
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Remover da lista',
                      onPressed: () => _removerVinculo(v),
                    ),
                    onTap: ativaId == v.id
                        ? null
                        : () => _trocarPara(v.id, nome: v.nome),
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.login),
                  title: const Text('Entrar em outra fazenda'),
                  subtitle: const Text('Use um código de convite'),
                  onTap: _entrarComCodigo,
                ),
              ],
            ),
    );
  }
}
