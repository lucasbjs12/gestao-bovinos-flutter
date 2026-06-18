import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_provider.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final nome = user?.displayName ?? '';
    final email = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nome,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          _SectionHeader('CONTA'),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Editar nome da fazenda'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editarNome(nome),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Alterar senha'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _alterarSenha,
          ),

          const Divider(),

          _SectionHeader('SESSÃO'),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sair'),
            onTap: _confirmarLogout,
          ),

          const Divider(),

          _SectionHeader('ZONA DE PERIGO'),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error),
            title: Text(
              'Excluir conta',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: _excluirConta,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _editarNome(String nomeAtual) async {
    final ctrl = TextEditingController(text: nomeAtual);
    final novo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nome da fazenda'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (!mounted || novo == null || novo.isEmpty) return;
    final ok = await context.read<AuthProvider>().atualizarNomeFazenda(novo);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Nome atualizado.' : 'Erro ao atualizar.'),
    ));
  }

  Future<void> _alterarSenha() async {
    final atualCtrl = TextEditingController();
    final novaCtrl = TextEditingController();
    final erro = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alterar senha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: atualCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Senha atual',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: novaCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nova senha',
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
            onPressed: () async {
              if (atualCtrl.text.isEmpty || novaCtrl.text.isEmpty) return;
              final err = await ctx.read<AuthProvider>().alterarSenha(
                    senhaAtual: atualCtrl.text,
                    novaSenha: novaCtrl.text,
                  );
              if (ctx.mounted) Navigator.pop(ctx, err ?? '');
            },
            child: const Text('Alterar'),
          ),
        ],
      ),
    );
    if (!mounted || erro == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(erro.isEmpty ? 'Senha alterada com sucesso.' : erro),
    ));
  }

  Future<void> _confirmarLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja sair da sua conta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (!mounted || ok != true) return;
    await context.read<AuthProvider>().logout();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _excluirConta() async {
    final senhaCtrl = TextEditingController();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir conta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta ação é irreversível. Todos os seus dados serão removidos.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: senhaCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirme sua senha',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (!mounted || confirmar != true) {
      senhaCtrl.dispose();
      return;
    }

    final senha = senhaCtrl.text;
    senhaCtrl.dispose();
    if (senha.isEmpty || !mounted) return;

    final auth = context.read<AuthProvider>();
    final uid = auth.currentUser?.uid;

    if (uid != null) {
      try {
        final fs = FirebaseFirestore.instance;
        final fazendaRef = fs.collection('fazendas').doc(uid);
        for (final col in [
          'bovinos', 'invernadas', 'eventos_sanitarios',
          'baixas_bovinos', 'movimentacoes',
        ]) {
          final snap = await fazendaRef.collection(col).get();
          for (final doc in snap.docs) {
            await doc.reference.delete();
          }
        }
        await fazendaRef.delete();
      } catch (_) {}
    }

    if (!mounted) return;
    final erro = await auth.excluirConta(senha);

    if (!mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro)),
      );
    } else {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
