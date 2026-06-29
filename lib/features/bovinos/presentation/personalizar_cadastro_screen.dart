import 'package:flutter/material.dart';

import '../data/campos_bovino_config.dart';

class PersonalizarCadastroScreen extends StatefulWidget {
  const PersonalizarCadastroScreen({super.key});

  @override
  State<PersonalizarCadastroScreen> createState() =>
      _PersonalizarCadastroScreenState();
}

class _PersonalizarCadastroScreenState
    extends State<PersonalizarCadastroScreen> {
  Map<CampoBovino, bool> _config = {};
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    CamposBovinoConfig.carregar().then((c) {
      if (mounted) setState(() { _config = c; _carregando = false; });
    });
  }

  Future<void> _salvar() async {
    await CamposBovinoConfig.salvar(_config);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuração salva.')),
    );
    Navigator.pop(context);
  }

  Future<void> _restaurarPadrao() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar padrão'),
        content: const Text('Todos os campos voltarão a ser exibidos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await CamposBovinoConfig.restaurarPadrao();
    final padrao = await CamposBovinoConfig.carregar();
    if (mounted) setState(() => _config = padrao);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalizar cadastro'),
        actions: [
          TextButton(
            onPressed: _restaurarPadrao,
            child: const Text('Restaurar padrão'),
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Escolha quais campos aparecem no cadastro de bovino. '
                    'Brinco e Categoria são obrigatórios e não podem ser removidos.',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),

                // ── Campos obrigatórios ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'OBRIGATÓRIOS',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                _CampoFixoTile(label: 'Brinco'),
                _CampoFixoTile(label: 'Categoria'),

                // ── Campos opcionais ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'OPCIONAIS',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),

                Expanded(
                  child: ListView(
                    children: CampoBovino.values.map((campo) {
                      return SwitchListTile(
                        title: Text(campo.label),
                        value: _config[campo] ?? true,
                        onChanged: (v) =>
                            setState(() => _config[campo] = v),
                      );
                    }).toList(),
                  ),
                ),

                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: FilledButton(
                      onPressed: _salvar,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Salvar'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CampoFixoTile extends StatelessWidget {
  final String label;
  const _CampoFixoTile({required this.label});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Switch(value: true, onChanged: null),
        ],
      ),
    );
  }
}
