import { NextFunction, Request, Response } from "express";
import { Papel } from "@prisma/client";
import { AppError } from "../exceptions/AppError";

export function exigirPapel(...papeis: Papel[]) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    if (!req.fazendaAtiva || !papeis.includes(req.fazendaAtiva.papel)) {
      throw AppError.proibido("Sua funcao na fazenda nao permite esta acao");
    }
    next();
  };
}
