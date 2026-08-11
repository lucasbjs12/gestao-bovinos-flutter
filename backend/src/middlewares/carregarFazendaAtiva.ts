import { Request, Response } from "express";
import { prisma } from "../config/prisma";
import { AppError } from "../exceptions/AppError";
import { membroRepository } from "../repositories/membro.repository";
import { asyncHandler } from "../utils/asyncHandler";

/**
 * Resolve a fazenda a partir de :fazendaId no path e confere se o usuario
 * autenticado e dono ou tem um Membro nela. Precisa vir depois de `autenticar`
 * e de uma rota montada com o segmento `/fazendas/:fazendaId/...`.
 */
export const carregarFazendaAtiva = asyncHandler(async (req: Request, _res: Response, next) => {
  const usuarioId = req.usuario!.id;
  const fazendaId = req.params.fazendaId;

  const fazenda = await prisma.fazenda.findUnique({ where: { id: fazendaId } });
  if (!fazenda) {
    throw AppError.naoEncontrado("Fazenda");
  }

  if (fazenda.donoId === usuarioId) {
    req.fazendaAtiva = { id: fazenda.id, donoId: fazenda.donoId, papel: "dono" };
    return next();
  }

  const membro = await membroRepository.buscar(fazenda.id, usuarioId);
  if (!membro) {
    throw AppError.proibido("Voce nao e membro desta fazenda");
  }

  req.fazendaAtiva = { id: fazenda.id, donoId: fazenda.donoId, papel: membro.papel };
  next();
});
