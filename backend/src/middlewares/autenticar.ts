import { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";
import { authService } from "../services/auth.service";
import { AppError } from "../exceptions/AppError";

export function autenticar(req: Request, _res: Response, next: NextFunction): void {
  const cabecalho = req.headers.authorization;
  if (!cabecalho?.startsWith("Bearer ")) {
    throw AppError.naoAutorizado("Token de acesso ausente");
  }

  const token = cabecalho.slice("Bearer ".length);
  try {
    const payload = authService.verificarAccessToken(token);
    req.usuario = { id: payload.sub, isAdmin: payload.isAdmin, nome: payload.nome };
    next();
  } catch (err) {
    if (err instanceof jwt.TokenExpiredError) {
      throw AppError.naoAutorizado("Token de acesso expirado");
    }
    throw AppError.naoAutorizado("Token de acesso invalido");
  }
}
