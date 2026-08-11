import { NextFunction, Request, Response } from "express";
import { ZodError } from "zod";
import { AppError } from "../exceptions/AppError";
import { logger } from "../config/logger";
import { erro } from "../utils/respostaPadrao";

export function errorHandler(
  err: unknown,
  req: Request,
  res: Response,
  _next: NextFunction,
): void {
  if (err instanceof AppError) {
    erro(res, err.statusCode, err.message, { code: err.code, details: err.details });
    return;
  }

  if (err instanceof ZodError) {
    erro(res, 422, "Dados invalidos", {
      code: "validation_error",
      details: err.issues.map((i) => ({ path: i.path.join("."), message: i.message })),
    });
    return;
  }

  logger.error({ err, path: req.path }, "Erro nao tratado");
  erro(res, 500, "Erro interno do servidor");
}

export function rotaNaoEncontrada(req: Request, res: Response): void {
  erro(res, 404, `Rota ${req.method} ${req.path} nao existe`);
}
