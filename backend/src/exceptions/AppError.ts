export class AppError extends Error {
  readonly statusCode: number;
  readonly code: string;
  readonly details?: unknown;

  constructor(statusCode: number, code: string, message: string, details?: unknown) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
  }

  static naoEncontrado(entidade: string): AppError {
    return new AppError(404, "not_found", `${entidade} nao encontrado(a)`);
  }

  static naoAutorizado(mensagem = "Nao autenticado"): AppError {
    return new AppError(401, "unauthorized", mensagem);
  }

  static proibido(mensagem = "Sem permissao para esta acao"): AppError {
    return new AppError(403, "forbidden", mensagem);
  }

  static conflito(mensagem: string): AppError {
    return new AppError(409, "conflict", mensagem);
  }

  static validacao(mensagem: string, details?: unknown): AppError {
    return new AppError(422, "validation_error", mensagem, details);
  }
}
