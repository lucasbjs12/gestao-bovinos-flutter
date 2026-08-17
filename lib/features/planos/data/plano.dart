enum PeriodicidadePlano { mensal, anual }

/// Plano comercial vindo do backend (`GET /planos`) -- valor e limite ficam
/// 100% no servidor, nunca hardcoded aqui (ver plano de assinaturas).
class Plano {
  final String id;
  final String slug;
  final String nome;
  final String? descricao;
  final PeriodicidadePlano periodicidade;
  final int valorCentavos;
  final int? limiteAnimais; // null = ilimitado
  final List<String> recursos;
  final bool destaque;

  const Plano({
    required this.id,
    required this.slug,
    required this.nome,
    this.descricao,
    required this.periodicidade,
    required this.valorCentavos,
    this.limiteAnimais,
    this.recursos = const [],
    this.destaque = false,
  });

  double get valorReais => valorCentavos / 100;

  /// Equivalente mensal do plano anual (pague 10, use 12) -- é isso que
  /// aparece em destaque no card, não o total cobrado de uma vez.
  double get valorMensalEquivalente =>
      periodicidade == PeriodicidadePlano.anual ? valorReais / 12 : valorReais;

  bool get gratuito => valorCentavos == 0;

  factory Plano.fromMap(Map<String, dynamic> m) {
    return Plano(
      id: m['id'] as String,
      slug: m['slug'] as String,
      nome: m['nome'] as String,
      descricao: m['descricao'] as String?,
      periodicidade: (m['periodicidade'] as String) == 'anual'
          ? PeriodicidadePlano.anual
          : PeriodicidadePlano.mensal,
      valorCentavos: m['valorCentavos'] as int,
      limiteAnimais: m['limiteAnimais'] as int?,
      recursos: (m['recursos'] as List?)?.cast<String>() ?? const [],
      destaque: m['destaque'] as bool? ?? false,
    );
  }
}
