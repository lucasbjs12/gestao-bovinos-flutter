import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _carregando = false;
  bool _senhaVisivel = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _fazerLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);

    final ok = await context.read<AuthProvider>().login(
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
    // Sucesso: AuthProvider muda status → _AuthGate redireciona automaticamente.
  }

  Future<void> _recuperarSenha() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o e-mail para recuperar a senha.')),
      );
      return;
    }
    try {
      await context.read<AuthProvider>().recuperarSenha(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('E-mail de recuperação enviado para $email.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar e-mail: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo / título
                  Icon(Icons.grass_rounded, size: 72, color: colorScheme.primary),
                  const SizedBox(height: 8),
                  Text(
                    'Gestão de Rebanho',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 40),

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
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _fazerLogin(),
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
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Informe a senha.' : null,
                  ),
                  const SizedBox(height: 8),

                  // Esqueci a senha
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _carregando ? null : _recuperarSenha,
                      child: const Text('Esqueci minha senha'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botão Entrar
                  FilledButton(
                    onPressed: _carregando ? null : _fazerLogin,
                    child: _carregando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Entrar'),
                  ),
                  const SizedBox(height: 12),

                  // Criar conta
                  OutlinedButton(
                    onPressed: _carregando
                        ? null
                        : () => Navigator.pushNamed(
                            context, AppRoutes.cadastroFazenda),
                    child: const Text('Criar minha conta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
