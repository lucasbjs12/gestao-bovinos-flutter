import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/marca_painter.dart';
import '../auth_provider.dart';

// ── Cores do design ────────────────────────────────────────────────────────────
const _verdeHero     = Color(0xFF1B5E20);
const _verdePrimario  = Color(0xFF2E7D32);
const _verdeLabel    = Color(0xFF52634F);
const _textoEscuro   = Color(0xFF1A1C19);
const _textoSub      = Color(0xFF6C6C70);
const _bordaCampo    = Color(0xFFC2C9BD);
const _hintCor       = Color(0xFF9aa098);

// Pinta a grande marca d'água no canto inferior direito do hero
class _HeroBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width - 168, size.height - 156);
    drawMarca(canvas, const Size(240, 240), Colors.white.withValues(alpha: 0.11));
    canvas.restore();
  }
  @override
  bool shouldRepaint(_HeroBgPainter o) => false;
}

// ── Screen ─────────────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _formKey   = GlobalKey<FormState>();
  bool _carregando    = false;
  bool _senhaVisivel  = false;

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
      _emailCtrl.text.trim(), _senhaCtrl.text,
    );
    if (!mounted) return;
    setState(() => _carregando = false);
    if (!ok) {
      final erro = context.read<AuthProvider>().error ?? 'Erro desconhecido.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
    }
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  // Campo com label separada acima (fiel ao design HTML)
  Widget _campo({
    required String label,
    required IconData icone,
    required TextEditingController ctrl,
    required String hint,
    TextInputType tipo = TextInputType.text,
    TextInputAction acao = TextInputAction.next,
    bool obscuro = false,
    Widget? sufixo,
    String? Function(String?)? validar,
    void Function(String)? aoSubmeter,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _verdeLabel,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: ctrl,
          keyboardType: tipo,
          textInputAction: acao,
          obscureText: obscuro,
          onFieldSubmitted: aoSubmeter,
          validator: validar,
          style: const TextStyle(fontSize: 15, color: _textoEscuro),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 15, color: _hintCor),
            prefixIcon: Icon(icone, size: 21, color: _verdeLabel),
            suffixIcon: sufixo,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            constraints: const BoxConstraints(minHeight: 54),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _bordaCampo, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _verdePrimario, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _verdeHero,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hero verde ─────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: CustomPaint(
              painter: _HeroBgPainter(),
              child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 30, 28, 80),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                        // Tile GR
                        SizedBox(
                          width: 84,
                          height: 84,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              children: [
                                Container(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                                Positioned(
                                  bottom: -10,
                                  right: -10,
                                  child: CustomPaint(
                                    size: const Size(56, 56),
                                    painter: MarcaPainter(
                                      Colors.white.withValues(alpha: 0.14),
                                    ),
                                  ),
                                ),
                                const Center(
                                  child: Text(
                                    'GR',
                                    style: TextStyle(
                                      fontSize: 42,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Gestão de Rebanho',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'SEU REBANHO NA PALMA DA MÃO',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.6),
                            letterSpacing: 1.5,
                          ),
                        ),
                ],
              ),
            ),
            ),
          ),

          // ── Card branco com overlap de -64dp ──────────────────────────
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -18,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Acesse sua conta',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                                color: _textoEscuro,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Gerencie seu rebanho de qualquer lugar.',
                              style: TextStyle(fontSize: 14, color: _textoSub),
                            ),
                            const SizedBox(height: 26),

                            // E-mail
                            _campo(
                              label: 'E-mail',
                              icone: Icons.mail_outline_rounded,
                              ctrl: _emailCtrl,
                              hint: 'Digite seu e-mail',
                              tipo: TextInputType.emailAddress,
                              validar: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Informe o e-mail.'
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            // Senha
                            _campo(
                              label: 'Senha',
                              icone: Icons.lock_outline_rounded,
                              ctrl: _senhaCtrl,
                              hint: 'Digite sua senha',
                              obscuro: !_senhaVisivel,
                              acao: TextInputAction.done,
                              aoSubmeter: (_) => _fazerLogin(),
                              sufixo: IconButton(
                                icon: Icon(
                                  _senhaVisivel
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 21,
                                  color: _verdeLabel,
                                ),
                                onPressed: () => setState(
                                    () => _senhaVisivel = !_senhaVisivel),
                              ),
                              validar: (v) => (v == null || v.isEmpty)
                                  ? 'Informe a senha.'
                                  : null,
                            ),

                            // Esqueci minha senha
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: _verdePrimario,
                                  textStyle: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 8),
                                ),
                                onPressed: _carregando ? null : _recuperarSenha,
                                child: const Text('Esqueci minha senha'),
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Botão Entrar
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _verdePrimario,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ).copyWith(
                                shadowColor: WidgetStateProperty.all(
                                  const Color(0x522E7D32),
                                ),
                                elevation: WidgetStateProperty.all(6),
                              ),
                              onPressed: _carregando ? null : _fazerLogin,
                              child: _carregando
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Entrar'),
                                        SizedBox(width: 8),
                                        Icon(Icons.arrow_forward_rounded, size: 20),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 22),

                            // Criar conta
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Não tem uma conta? ',
                                  style: TextStyle(
                                      fontSize: 14, color: _verdeLabel),
                                ),
                                GestureDetector(
                                  onTap: _carregando
                                      ? null
                                      : () => Navigator.pushNamed(
                                          context, AppRoutes.cadastroFazenda),
                                  child: const Text(
                                    'Cadastre-se',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _verdePrimario,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
