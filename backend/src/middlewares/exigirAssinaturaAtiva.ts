import { Request, Response } from "express";
import { AppError } from "../exceptions/AppError";
import { usuarioRepository } from "../repositories/usuario.repository";
import { asyncHandler } from "../utils/asyncHandler";

/**
 * Verifica a assinatura do DONO da fazenda ativa (nao a do usuario logado) --
 * um convidado so opera se a assinatura de quem possui a fazenda estiver em dia.
 * Precisa rodar depois de carregarFazendaAtiva.
 */
export const exigirAssinaturaAtiva = asyncHandler(async (req: Request, _res: Response, next) => {
  const fazendaAtiva = req.fazendaAtiva;
  if (!fazendaAtiva) {
    throw AppError.naoEncontrado("Fazenda");
  }

  const dono = await usuarioRepository.buscarPorId(fazendaAtiva.donoId);
  if (!dono) {
    throw AppError.naoEncontrado("Dono da fazenda");
  }

  const vencida = dono.vencimento !== null && dono.vencimento < new Date();
  const liberado = dono.isAdmin || (dono.statusAssinatura === "ativo" && !vencida);

  if (!liberado) {
    throw AppError.proibido("A assinatura desta fazenda nao esta ativa");
  }

  next();
});
