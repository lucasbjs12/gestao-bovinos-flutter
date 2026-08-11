export class ApiException extends Error {
  statusCode: number;
  codigo?: string;

  constructor(statusCode: number, message: string, codigo?: string) {
    super(message);
    this.name = "ApiException";
    this.statusCode = statusCode;
    this.codigo = codigo;
  }
}
