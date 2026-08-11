import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';

/// Bifurcação do cadastro: produtor (dono, paga) ou convidado (grátis, entra
/// com código na fazenda de um produtor).
class EscolhaCadastroScreen extends StatelessWidget {
  const EscolhaCadastroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const Text(
              'Como você vai usar o app?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Escolha a opção que combina com você.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6C6C70)),
            ),
            const SizedBox(height: 24),
            _OpcaoCard(
              cor: const Color(0xFF2E7D32),
              corFundo: const Color(0xFFEAF3DE),
              icone: Icons.agriculture_outlined,
              titulo: 'Sou produtor rural',
              descricao:
                  'Cadastro a minha fazenda e gerencio o meu rebanho. Posso '
                  'convidar pessoas para ajudar.',
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.cadastroFazenda),
            ),
            const SizedBox(height: 16),
            _OpcaoCard(
              cor: const Color(0xFF9A5E0C),
              corFundo: const Color(0xFFFAEEDA),
              icone: Icons.badge_outlined,
              titulo: 'Fui convidado',
              descricao:
                  'Vou ajudar na fazenda de um produtor. Entro com um código '
                  'de convite — sem custo.',
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.cadastroConvidado),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpcaoCard extends StatelessWidget {
  final Color cor;
  final Color corFundo;
  final IconData icone;
  final String titulo;
  final String descricao;
  final VoidCallback onTap;

  const _OpcaoCard({
    required this.cor,
    required this.corFundo,
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: corFundo,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icone, color: cor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      descricao,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF6C6C70), height: 1.35),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF9E9E9E)),
            ],
          ),
        ),
      ),
    );
  }
}
