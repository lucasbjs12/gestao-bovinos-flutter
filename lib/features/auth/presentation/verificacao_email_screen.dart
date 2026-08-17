import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_provider.dart';

class VerificacaoEmailScreen extends StatefulWidget {
  const VerificacaoEmailScreen({super.key});

  @override
  State<VerificacaoEmailScreen> createState() => _VerificacaoEmailScreenState();
}

class _VerificacaoEmailScreenState extends State<VerificacaoEmailScreen> {
  bool _verificando = false;

  Future<void> _verificar() async {
    setState(() => _verificando = true);
    final confirmado = await context.read<AuthProvider>().verificarEmail();
    if (!mounted) return;
    setState(() => _verificando = false);

    if (!confirmado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Ainda não confirmado. Abra o link no seu e-mail e tente de novo.'),
        ),
      );
    }
    // Sucesso: AuthProvider → status authenticated → _AuthGate mostra MainShellScreen.
  }

  Future<void> _reenviar() async {
    try {
      await context.read<AuthProvider>().reenviarVerificacao();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail de confirmação reenviado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao reenviar: $e')),
      );
    }
  }

  Future<void> _usarOutraConta() async {
    await context.read<AuthProvider>().logout();
    // AuthProvider → status unauthenticated → _AuthGate mostra LoginScreen.
  }

  @override
  Widget build(BuildContext context) {
    final email = context.read<AuthProvider>().currentUser?.email ?? '';
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mark_email_unread_outlined,
                    size: 72, color: colorScheme.primary),
                const SizedBox(height: 24),
                Text(
                  'Confirme seu e-mail',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Enviamos um link de confirmação para:',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Abra o link no e-mail e depois toque em "Já confirmei".',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),

                // Já confirmei
                FilledButton(
                  onPressed: _verificando ? null : _verificar,
                  child: _verificando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Já confirmei'),
                ),
                const SizedBox(height: 12),

                // Reenviar
                OutlinedButton(
                  onPressed: _reenviar,
                  child: const Text('Reenviar e-mail'),
                ),
                const SizedBox(height: 8),

                // Usar outra conta
                TextButton(
                  onPressed: _usarOutraConta,
                  child: const Text('Usar outra conta'),
                ),
                const SizedBox(height: 24),

                // Não achou o e-mail? Dica de onde procurar -- Outlook/Hotmail
                // separam e-mail transacional novo numa aba "Outras", diferente
                // do Spam, que muita gente nunca confere.
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 18, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Não achou o e-mail? Confira a pasta de Spam/Lixo eletrônico. '
                          'No Outlook/Hotmail, olhe também a aba "Outras", ao lado de '
                          '"Focada" — é diferente do Spam e costuma passar despercebida.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
