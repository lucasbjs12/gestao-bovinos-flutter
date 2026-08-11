import { Request, Response } from "express";
import { movimentacaoService } from "../services/movimentacao.service";
import { sucesso } from "../utils/respostaPadrao";
import type { CriarMovimentacaoInput } from "../dtos/movimentacao.dto";

export const movimentacaoController = {
  async criar(req: Request<unknown, unknown, CriarMovimentacaoInput>, res: Response) {
    const movimentacao = await movimentacaoService.criar(req.fazendaAtiva!.id, req.body, {
      id: req.usuario!.id,
      nome: req.usuario!.nome,
    });
    sucesso(res, movimentacao, "Movimentacao registrada", 201);
  },
};
