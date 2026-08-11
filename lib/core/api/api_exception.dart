/// Erro vindo do backend proprio -- espelha o formato de erro padronizado
/// da API (`{ success: false, message, error }`).
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? codigo;

  const ApiException({required this.statusCode, required this.message, this.codigo});

  @override
  String toString() => 'ApiException($statusCode, $codigo): $message';
}
