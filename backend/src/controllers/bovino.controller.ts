import { Request, Response } from "express";
import { bovinoService } from "../services/bovino.service";
import { sucesso } from "../utils/respostaPadrao";
import { respostaPaginada } from "../utils/paginacaoResposta";
import type { AtualizarBovinoInput, CriarBovinoInput, ListarBovinosQuery, RegistrarBaixaInput } from "../dtos/bovino.dto";

export const bovinoController = {
  async listar(req: Request, res: Response) {
    const query = req.query as unknown as ListarBovinosQuery;
    const { itens, total } = await bovinoService.listar(req.fazendaAtiva!.id, query);
    sucesso(res, respostaPaginada(itens, total, query.page, query.pageSize));
  },

  async buscarPorId(req: Request<{ id: string }>, res: Response) {
    const bovino = await bovinoService.buscarPorId(req.fazendaAtiva!.id, req.params.id);
    sucesso(res, bovino);
  },

  async criar(req: Request<unknown, unknown, CriarBovinoInput>, res: Response) {
    const bovino = await bovinoService.criar(req.fazendaAtiva!.id, req.body, {
      id: req.usuario!.id,
      nome: req.usuario!.nome,
    });
    sucesso(res, bovino, "Bovino cadastrado", 201);
  },

  async atualizar(req: Request<{ id: string }, unknown, AtualizarBovinoInput>, res: Response) {
    const bovino = await bovinoService.atualizar(req.fazendaAtiva!.id, req.params.id, req.body, {
      id: req.usuario!.id,
      nome: req.usuario!.nome,
    });
    sucesso(res, bovino, "Bovino atualizado");
  },

  async remover(req: Request<{ id: string }>, res: Response) {
    await bovinoService.remover(req.fazendaAtiva!.id, req.params.id, {
      id: req.usuario!.id,
      nome: req.usuario!.nome,
    });
    res.status(204).end();
  },

  async registrarBaixa(req: Request<{ id: string }, unknown, RegistrarBaixaInput>, res: Response) {
    const bovino = await bovinoService.registrarBaixa(req.fazendaAtiva!.id, req.params.id, req.body, {
      id: req.usuario!.id,
      nome: req.usuario!.nome,
    });
    sucesso(res, bovino, "Baixa registrada");
  },

  async reativar(req: Request<{ id: string }>, res: Response) {
    const bovino = await bovinoService.reativar(req.fazendaAtiva!.id, req.params.id, {
      id: req.usuario!.id,
      nome: req.usuario!.nome,
    });
    sucesso(res, bovino, "Bovino reativado");
  },
};
