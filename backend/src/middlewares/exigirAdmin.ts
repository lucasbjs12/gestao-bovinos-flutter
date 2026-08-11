import { NextFunction, Request, Response } from "express";
import { AppError } from "../exceptions/AppError";

export function exigirAdmin(req: Request, _res: Response, next: NextFunction): void {
  if (!req.usuario?.isAdmin) {
    throw AppError.proibido("Acesso restrito a administradores");
  }
  next();
}
