class Convite {
  final String codigo;
  final String fazendaId;
  final String papel;
  final String? criadoPorNome;
  final DateTime expiraEm;
  final bool usado;

  const Convite({
    required this.codigo,
    required this.fazendaId,
    required this.papel,
    this.criadoPorNome,
    required this.expiraEm,
    required this.usado,
  });

  bool get expirado => DateTime.now().isAfter(expiraEm);
  bool get valido => !usado && !expirado;

  /// Formato do backend próprio (`GET /convites/:codigo` ou o item retornado
  /// por `POST /fazendas/:id/convites`).
  factory Convite.fromBackend(Map<String, dynamic> m) => Convite(
        codigo: m['codigo'] as String,
        fazendaId: m['fazendaId'] as String? ?? '',
        papel: m['papel'] as String? ?? 'convidado',
        criadoPorNome:
            (m['fazenda'] as Map<String, dynamic>?)?['nome'] as String?,
        expiraEm: DateTime.tryParse(m['expiraEm'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        usado: m['usado'] as bool? ?? false,
      );
}
