import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_provider.dart';
import '../data/usuario_assinatura.dart';

class AcessoBloqueadoScreen extends StatelessWidget {
  final UsuarioAssinatura assinatura;
  const AcessoBloqueadoScreen({super.key, required this.assinatura});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPendente = assinatura.statusEfetivo == StatusAssinatura.pendente;
    final isBloqueado = assinatura.statusEfetivo == StatusAssinatura.bloqueado;

    final titulo = isPendente
        ? 'Conta aguardando ativação'
        : isBloqueado
            ? 'Conta bloqueada'
            : 'Assinatura vencida';

    final mensagem = isPendente
        ? 'Sua conta está aguardando ativação. Entre em contato com o suporte para liberar o acesso.'
        : isBloqueado
            ? 'Sua conta foi bloqueada. Entre em contato com o suporte para mais informações.'
            : 'Sua assinatura venceu. Entre em contato com o suporte — sua conta está com débitos pendentes.';

    final icone = isPendente
        ? Icons.hourglass_empty_outlined
        : isBloqueado
            ? Icons.block_outlined
            : Icons.credit_card_off_outlined;

    final cor = isPendente ? cs.primary : cs.error;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, size: 72, color: cor),
              const SizedBox(height: 24),
              Text(
                titulo,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                mensagem,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.support_agent_outlined),
                label: const Text('Falar com o suporte'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await context.read<AuthProvider>().logout();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sair da conta'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
