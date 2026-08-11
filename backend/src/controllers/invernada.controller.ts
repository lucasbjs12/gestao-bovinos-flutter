import { Request, Response } from "express";
import { invernadaService } from "../services/invernada.service";
import { sucesso } from "../utils/respostaPadrao";
import { respostaPaginada } from "../utils/paginacaoResposta";
import type { PaginacaoQuery } from "../dtos/paginacao.dto";
import type { AtualizarInvernadaInput, CriarInvernadaInput } from "../dtos/invernada.dto";

export const invernadaController = {
  async listar(req: Request, res: Response) {
    const { page, pageSize, busca } = req.query as unknown as PaginacaoQuery;
    const { itens, total } = await invernadaService.listar(
      req.fazendaAtiva!.id,
      page,
      pageSize,
      busca,
    );
    sucesso(res, respostaPaginada(itens, total, page, pageSize));
  },

  async buscarPorId(req: Request<{ id: string }>, res: Response) {
    const invernada = await invernadaService.buscarPorId(req.fazendaAtiva!.id, req.params.id);
    sucesso(res, invernada);
  },

  async criar(req: Request<unknown, unknown, CriarInvernadaInput>, res: Response) {
    const invernada = await invernadaService.criar(req.fazendaAtiva!.id, req.body, {
      id: req.usuario!.id,
      nome: req.usuario!.nome,
    });
    sucesso(res, invernada, "Invernada criada", 201);
  },

  async atualizar(req: Request<{ id: string }, unknown, AtualizarInvernadaInput>, res: Response) {
    const invernada = await invernadaService.atualizar(
      req.fazendaAtiva!.id,
      req.params.id,
      req.body,
      { id: req.usuario!.id, nome: req.usuario!.nome },
    );
    sucesso(res, invernada, "Invernada atualizada");
  },

  async remover(req: Request<{ id: string }>, res: Response) {
    await invernadaService.remover(req.fazendaAtiva!.id, req.params.id, {
      id: req.usuario!.id,
      nome: req.usuario!.nome,
    });
    res.status(204).end();
  },

  async listarMovimentacoes(req: Request<{ id: string }>, res: Response) {
    const { page, pageSize } = req.query as unknown as PaginacaoQuery;
    const movimentacoes = await invernadaService.listarMovimentacoes(
      req.fazendaAtiva!.id,
      req.params.id,
      page,
      pageSize,
    );
    sucesso(res, movimentacoes);
  },
};
