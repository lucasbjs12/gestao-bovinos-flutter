import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/db/app_database.dart';
import '../../../core/routes/app_routes.dart';
import '../../onboarding/presentation/onboarding_screen.dart';
// import '../../admin/data/assinatura_service.dart';
// import '../../admin/data/usuario_assinatura.dart';
import '../../auth/auth_provider.dart';
import '../../bovinos/data/bovino_local_repository.dart';

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

          _SectionHeader('DADOS'),
          ListTile(
            leading: const Icon(Icons.tune_outlined),
            title: const Text('Personalizar cadastro de bovino'),
            subtitle: const Text('Escolha quais campos aparecem no formulário'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, AppRoutes.personalizarCadastro),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Exportar rebanho (CSV)'),
            subtitle: const Text('Compartilhar planilha com todos os animais'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _exportarCSV,
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Diário de atividades'),
            subtitle: const Text('Tudo o que foi feito no app, dia a dia'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, AppRoutes.diarioAtividades),
          ),

          const Divider(),

          _SectionHeader('SESSÃO'),
          ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: const Text('Ver introdução novamente'),
            onTap: _verIntroducao,
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sair'),
            onTap: _confirmarLogout,
          ),

          const Divider(),

          _SectionHeader('SOBRE'),
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: const Text('Visite nosso site'),
            trailing: const Icon(Icons.open_in_new),
            onTap: _abrirSite,
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Política de privacidade'),
            trailing: const Icon(Icons.open_in_new),
            onTap: _abrirPoliticaPrivacidade,
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

  Future<void> _exportarCSV() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;

    final db = await AppDatabase.instance.instanceFor(uid);
    final bovinos = await BovinoLocalRepository(db).listarAtivos();

    if (!mounted) return;

    if (bovinos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum animal cadastrado para exportar.')),
      );
      return;
    }

    final buf = StringBuffer();
    buf.writeln(
      'Brinco;Nome;Categoria;Sexo;Raça;Pelagem;Peso (kg);'
      'Nascimento;Origem;Invernada;Status;Observações',
    );

    for (final b in bovinos) {
      String esc(String? v) {
        if (v == null || v.isEmpty) return '';
        if (v.contains(';') || v.contains('"') || v.contains('\n')) {
          return '"${v.replaceAll('"', '""')}"';
        }
        return v;
      }

      buf.writeln([
        esc(b.numeroBrinco),
        esc(b.nomeAnimal),
        esc(b.categoria),
        esc(b.sexo),
        esc(b.raca),
        esc(b.pelagem),
        b.pesoAtualKg != null
            ? b.pesoAtualKg!.toStringAsFixed(1).replaceAll('.', ',')
            : '',
        esc(b.dataNascimento),
        esc(b.origem),
        esc(b.invernadaDescricao),
        esc(b.status),
        esc(b.observacoes),
      ].join(';'));
    }

    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final fileName =
        'rebanho_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buf.toString(), encoding: utf8);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Rebanho — $fileName',
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

  Future<void> _abrirSite() async {
    final uri = Uri.parse('https://gestaobovinosapp.web.app/');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir o site.')),
    );
  }

  Future<void> _abrirPoliticaPrivacidade() async {
    final uri = Uri.parse('https://gestaobovinosapp.web.app/privacidade.html');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir a página.')),
    );
  }

  Future<void> _verIntroducao() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('onboarding_shown_v1');
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OnboardingScreen(onConcluir: () => Navigator.of(context).pop()),
      ),
    );
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
    // Retorna a senha digitada ou null se cancelado.
    // O controller fica inteiramente dentro do builder para evitar
    // dispose enquanto a animação de fechamento ainda está rodando.
    final senha = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
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
                controller: ctrl,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Confirme sua senha',
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
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (!mounted || senha == null || senha.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final uid  = auth.currentUser?.uid;

    // 1. Verificar a senha antes de tocar em qualquer dado
    final erroAuth = await auth.reautenticar(senha);
    if (!mounted) return;
    if (erroAuth != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erroAuth)));
      return;
    }

    // 2. Senha correta — agora sim deleta os dados do Firestore
    if (uid != null) {
      try {
        final fs = FirebaseFirestore.instance;
        final fazendaRef = fs.collection('fazendas').doc(uid);
        for (final col in [
          'bovinos', 'invernadas', 'eventos_sanitarios',
          'baixas_bovinos', 'movimentacoes', 'atividades', 'membros',
        ]) {
          final snap = await fazendaRef.collection(col).get();
          for (final doc in snap.docs) {
            await doc.reference.delete();
          }
        }
        await fazendaRef.delete();
      } catch (_) {}
    }

    // 3. Deleta a conta de autenticação
    if (!mounted) return;
    final erro = await auth.excluirConta(senha);

    if (!mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
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
