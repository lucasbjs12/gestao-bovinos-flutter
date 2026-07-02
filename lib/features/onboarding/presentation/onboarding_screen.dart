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

const _verde = Color(0xFF2E7D32);
const _verdeClaro = Color(0xFFE8F5E9);

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
      titulo: 'Bem-vindo ao\nGestão de Rebanho',
      descricao: 'Controle do seu rebanho bovino na palma da mão, onde quer que você esteja.',
    ),
    _PaginaInfo(
      icon: Icons.label_rounded,
      titulo: 'Cadastre seus animais',
      descricao: 'Brinco, categoria, peso e invernada. Adicione um por um ou em lote no dia do manejo.',
    ),
    _PaginaInfo(
      icon: Icons.grass_rounded,
      titulo: 'Organize em invernadas',
      descricao: 'Veja qual pasto está lotado, mova lotes inteiros e controle a lotação em kg/ha.',
    ),
    _PaginaInfo(
      icon: Icons.check_circle_rounded,
      titulo: 'Tudo pronto!',
      descricao: 'Seus dados ficam salvos localmente e sincronizam na nuvem. Funciona mesmo sem internet.',
      ultima: true,
    ),
  ];

  void _avancar() {
    if (_pagina < _paginas.length - 1) {
      _ctrl.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
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
    final pagina   = _paginas[_pagina];
    final total    = _paginas.length;
    final ultima   = pagina.ultima;
    final progresso = (_pagina + 1) / total;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Barra de progresso + Pular ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_pagina + 1} de $total',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progresso,
                            minHeight: 5,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(_verde),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!ultima) ...[
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: _concluir,
                      style: TextButton.styleFrom(foregroundColor: Colors.grey.shade500),
                      child: const Text('Pular'),
                    ),
                  ],
                ],
              ),
            ),

            // ── Páginas ─────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                onPageChanged: (i) => setState(() => _pagina = i),
                itemCount: _paginas.length,
                itemBuilder: (_, i) => _PaginaWidget(info: _paginas[i], ativa: i == _pagina),
              ),
            ),

            // ── Dots + Botão ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(total, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _pagina ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _pagina ? _verde : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _verde,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _avancar,
                      child: Text(
                        ultima ? 'Começar agora →' : 'Próximo',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
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
  final bool ativa;
  const _PaginaWidget({required this.info, required this.ativa});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ícone animado
          AnimatedScale(
            scale: ativa ? 1.0 : 0.85,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _verdeClaro,
                boxShadow: [
                  BoxShadow(
                    color: _verde.withValues(alpha: 0.18),
                    blurRadius: 40,
                    spreadRadius: 8,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Icon(info.icon, size: 80, color: _verde),
            ),
          ),
          const SizedBox(height: 48),

          // Título
          AnimatedOpacity(
            opacity: ativa ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 350),
            child: Text(
              info.titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Descrição
          AnimatedOpacity(
            opacity: ativa ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: Text(
              info.descricao,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaginaInfo {
  final IconData icon;
  final String titulo;
  final String descricao;
  final bool ultima;

  const _PaginaInfo({
    required this.icon,
    required this.titulo,
    required this.descricao,
    this.ultima = false,
  });
}
