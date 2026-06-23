import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kOnboardingKey = 'onboarding_shown_v1';

Future<bool> onboardingJaMostrado() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingKey) ?? false;
}

Future<void> marcarOnboardingMostrado() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingKey, true);
}

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onConcluir;
  const OnboardingScreen({super.key, required this.onConcluir});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _pagina = 0;

  static const _paginas = [
    _PaginaInfo(
      icon: Icons.pets_rounded,
      cor: Color(0xFF2E7D32),
      titulo: 'Bem-vindo ao Gestão Bovinos',
      descricao:
          'Gerencie seu rebanho de forma simples e eficiente. '
          'Cadastre animais, acompanhe manejos e sincronize tudo na nuvem.',
    ),
    _PaginaInfo(
      icon: Icons.grass_rounded,
      cor: Color(0xFF1565C0),
      titulo: 'Organize por Invernadas',
      descricao:
          'Distribua seus animais em invernadas e mova lotes inteiros '
          'com a seleção em massa. Toque longo em qualquer animal para selecionar.',
    ),
    _PaginaInfo(
      icon: Icons.medical_services_rounded,
      cor: Color(0xFF6A1B9A),
      titulo: 'Controle de Manejos',
      descricao:
          'Registre vacinas, vermifugações e outros manejos sanitários. '
          'O app destaca os animais que estão há mais de 90 dias sem manejo.',
    ),
    _PaginaInfo(
      icon: Icons.cloud_sync_rounded,
      cor: Color(0xFF00838F),
      titulo: 'Sempre Sincronizado',
      descricao:
          'Seus dados ficam salvos localmente e sincronizam automaticamente '
          'com a nuvem quando houver conexão. Funciona offline também.',
    ),
  ];

  void _avancar() {
    if (_pagina < _paginas.length - 1) {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _concluir();
    }
  }

  Future<void> _concluir() async {
    await marcarOnboardingMostrado();
    widget.onConcluir();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ultima = _pagina == _paginas.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _concluir,
                child: const Text('Pular'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                onPageChanged: (i) => setState(() => _pagina = i),
                itemCount: _paginas.length,
                itemBuilder: (_, i) => _PaginaWidget(info: _paginas[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _paginas.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _pagina ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _pagina
                              ? _paginas[_pagina].cor
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _paginas[_pagina].cor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _avancar,
                      child: Text(
                        ultima ? 'Começar' : 'Próximo',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _concluir,
                    child: Text(
                      ultima ? 'Pular introdução' : 'Não mostrar novamente',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginaWidget extends StatelessWidget {
  final _PaginaInfo info;
  const _PaginaWidget({required this.info});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: info.cor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(info.icon, size: 60, color: info.cor),
          ),
          const SizedBox(height: 40),
          Text(
            info.titulo,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: info.cor,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            info.descricao,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _PaginaInfo {
  final IconData icon;
  final Color cor;
  final String titulo;
  final String descricao;
  const _PaginaInfo({
    required this.icon,
    required this.cor,
    required this.titulo,
    required this.descricao,
  });
}
