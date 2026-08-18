import 'package:flutter/material.dart';

import '../../features/bovinos/data/bovino.dart';

/// Mapeamento único cor→Color e cor→rótulo em português, usado em toda
/// tela que exibe ou escolhe o destaque visual de um bovino.
Color corDoDestaque(CorDestaque cor) {
  return switch (cor) {
    CorDestaque.amarelo => const Color(0xFFF2C230),
    CorDestaque.azul => const Color(0xFF3B82F6),
    CorDestaque.verde => const Color(0xFF22A55A),
    CorDestaque.vermelho => const Color(0xFFE0453D),
    CorDestaque.roxo => const Color(0xFF8B5CF6),
    CorDestaque.laranja => const Color(0xFFF2822F),
  };
}

String nomeDoDestaque(CorDestaque cor) {
  return switch (cor) {
    CorDestaque.amarelo => 'Amarelo',
    CorDestaque.azul => 'Azul',
    CorDestaque.verde => 'Verde',
    CorDestaque.vermelho => 'Vermelho',
    CorDestaque.roxo => 'Roxo',
    CorDestaque.laranja => 'Laranja',
  };
}

/// Bolinha colorida compacta — usada na lista de bovinos e no perfil.
class DestaqueDot extends StatelessWidget {
  const DestaqueDot({super.key, required this.cor, this.size = 12});

  final CorDestaque cor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: corDoDestaque(cor),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}

/// Seletor de cor em chips — usado no fluxo de evento em lote e na
/// ação "Destacar" da lista de bovinos.
class SeletorCorDestaque extends StatelessWidget {
  const SeletorCorDestaque({
    super.key,
    required this.selecionada,
    required this.onSelecionar,
  });

  final CorDestaque? selecionada;
  final ValueChanged<CorDestaque?> onSelecionar;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: CorDestaque.values.map((cor) {
        final ativa = cor == selecionada;
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onSelecionar(ativa ? null : cor),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: corDoDestaque(cor),
              shape: BoxShape.circle,
              border: Border.all(
                color: ativa ? Colors.black87 : Colors.black12,
                width: ativa ? 2.5 : 1,
              ),
            ),
            child: ativa
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
