import { Request, Response } from "express";
import { atividadeRepository } from "../repositories/atividade.repository";
import { sucesso } from "../utils/respostaPadrao";
import { respostaPaginada } from "../utils/paginacaoResposta";
import type { PaginacaoQuery } from "../dtos/paginacao.dto";

export const atividadeController = {
  async listar(req: Request, res: Response) {
    const { page, pageSize } = req.query as unknown as PaginacaoQuery;
    const fazendaId = req.fazendaAtiva!.id;
    const [itens, total] = await Promise.all([
      atividadeRepository.listarPorFazenda(fazendaId, page, pageSize),
      atividadeRepository.contarPorFazenda(fazendaId),
    ]);
    sucesso(res, respostaPaginada(itens, total, page, pageSize));
  },
};
