import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../fazenda/data/fazenda_membros_service.dart';
import '../auth_provider.dart';

/// Tela do convidado autenticado que ainda não entrou em nenhuma fazenda.
/// O sistema fica bloqueado até um código de convite válido destravá-lo.
class ConvidadoEntrarScreen extends StatefulWidget {
  const ConvidadoEntrarScreen({super.key});

  @override
  State<ConvidadoEntrarScreen> createState() => _ConvidadoEntrarScreenState();
}

class _ConvidadoEntrarScreenState extends State<ConvidadoEntrarScreen> {
  final _codigoCtrl = TextEditingController();
  bool _processando = false;

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final codigo = _codigoCtrl.text.trim();
    if (codigo.isEmpty) return;
    setState(() => _processando = true);
    try {
      final r = await FazendaMembrosService.aceitarConvite(codigo);
      if (!mounted) return;
      await context.read<AuthProvider>().entrarNaFazenda(r.fazendaId, nome: r.nome);
      // O AuthGate re-roteia para o app assim que a fazenda ativa muda.
    } catch (e) {
      if (!mounted) return;
      setState(() => _processando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFF9A5E0C);
    final nome = context.read<AuthProvider>().currentUser?.displayName ?? '';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAEEDA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.badge_outlined, color: amber, size: 36),
              ),
              const SizedBox(height: 24),
              Text(
                nome.isEmpty ? 'Bem-vindo!' : 'Olá, $nome',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Você entrou como convidado. Para acessar o rebanho, digite o '
                'código de convite que o dono da fazenda compartilhou com você.',
                style: TextStyle(fontSize: 15, color: Color(0xFF6C6C70), height: 1.4),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _codigoCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
                inputFormatters: [UpperCaseFormatter()],
                decoration: InputDecoration(
                  hintText: 'BOV-XXXXXX',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onSubmitted: (_) => _entrar(),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: amber,
                  minimumSize: const Size.fromHeight(54),
                ),
                onPressed: _processando ? null : _entrar,
                child: _processando
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Acessar a fazenda'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.read<AuthProvider>().logout(),
                child: const Text('Sair'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Força o texto digitado para maiúsculas (código de convite).
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
