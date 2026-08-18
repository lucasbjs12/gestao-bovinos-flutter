/// Erro vindo do backend proprio -- espelha o formato de erro padronizado
/// da API (`{ success: false, message, error }`).
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? codigo;

  const ApiException({required this.statusCode, required this.message, this.codigo});

  /// Erro de regra de negócio (ex: limite do plano, brinco duplicado) --
  /// reenviar não vai adiantar nunca, então nunca deve entrar na fila de
  /// retry do [Outbox] nem ser tratado como "offline, tenta depois". 401
  /// (token expirado, já tratado com refresh antes de chegar aqui) e 429
  /// (rate limit) ficam de fora por serem passageiros.
  bool get ehPermanente =>
      statusCode >= 400 && statusCode < 500 && statusCode != 401 && statusCode != 429;

  @override
  String toString() => 'ApiException($statusCode, $codigo): $message';
}
