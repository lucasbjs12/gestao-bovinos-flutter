import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_provider.dart';

class CadastroFazendaScreen extends StatefulWidget {
  const CadastroFazendaScreen({super.key});

  @override
  State<CadastroFazendaScreen> createState() => _CadastroFazendaScreenState();
}

class _CadastroFazendaScreenState extends State<CadastroFazendaScreen> {
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _carregando = false;
  bool _senhaVisivel = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    _confirmarCtrl.dispose();
    super.dispose();
  }

  Future<void> _criarConta() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);

    final ok = await context.read<AuthProvider>().cadastrar(
          _nomeCtrl.text.trim(),
          _emailCtrl.text.trim(),
          _senhaCtrl.text,
        );

    if (!mounted) return;
    setState(() => _carregando = false);

    if (!ok) {
      final erro = context.read<AuthProvider>().error ?? 'Erro desconhecido.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    }
    // Sucesso: AuthProvider → status unverified → _AuthGate mostra VerificacaoEmailScreen.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Nome da fazenda
                TextFormField(
                  controller: _nomeCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nome da fazenda',
                    prefixIcon: Icon(Icons.home_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Informe o nome da fazenda.' : null,
                ),
                const SizedBox(height: 16),

                // E-mail
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Informe o e-mail.' : null,
                ),
                const SizedBox(height: 16),

                // Senha
                TextFormField(
                  controller: _senhaCtrl,
                  obscureText: !_senhaVisivel,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_senhaVisivel
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () =>
                          setState(() => _senhaVisivel = !_senhaVisivel),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe a senha.';
                    if (v.length < 6) return 'A senha deve ter pelo menos 6 caracteres.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirmar senha
                TextFormField(
                  controller: _confirmarCtrl,
                  obscureText: !_senhaVisivel,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _criarConta(),
                  decoration: const InputDecoration(
                    labelText: 'Confirmar senha',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirme a senha.';
                    if (v != _senhaCtrl.text) return 'As senhas não coincidem.';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Botão criar
                FilledButton(
                  onPressed: _carregando ? null : _criarConta,
                  child: _carregando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Criar minha conta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
