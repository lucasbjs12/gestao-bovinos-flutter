import { Request, Response } from "express";
import { eventoSanitarioService } from "../services/eventoSanitario.service";
import { sucesso } from "../utils/respostaPadrao";
import { respostaPaginada } from "../utils/paginacaoResposta";
import type {
  AtualizarEventoSanitarioInput,
  CriarEventoSanitarioInput,
  ListarEventosSanitariosQuery,
} from "../dtos/eventoSanitario.dto";

export const eventoSanitarioController = {
  async listar(req: Request, res: Response) {
    const query = req.query as unknown as ListarEventosSanitariosQuery;
    const { itens, total } = await eventoSanitarioService.listar(req.fazendaAtiva!.id, query);
    sucesso(res, respostaPaginada(itens, total, query.page, query.pageSize));
  },

  async buscarPorId(req: Request<{ id: string }>, res: Response) {
    const evento = await eventoSanitarioService.buscarPorId(req.fazendaAtiva!.id, req.params.id);
    sucesso(res, evento);
  },

  async criar(req: Request<unknown, unknown, CriarEventoSanitarioInput>, res: Response) {
    const evento = await eventoSanitarioService.criar(req.fazendaAtiva!.id, req.body, {
      id: req.usuario!.id,
      nome: req.usuario!.nome,
    });
    sucesso(res, evento, "Evento sanitario registrado", 201);
  },

  async atualizar(req: Request<{ id: string }, unknown, AtualizarEventoSanitarioInput>, res: Response) {
    const evento = await eventoSanitarioService.atualizar(
      req.fazendaAtiva!.id,
      req.params.id,
      req.body,
      { id: req.usuario!.id, nome: req.usuario!.nome },
    );
    sucesso(res, evento, "Evento sanitario atualizado");
  },

  async remover(req: Request<{ id: string }>, res: Response) {
    await eventoSanitarioService.remover(req.fazendaAtiva!.id, req.params.id, {
      id: req.usuario!.id,
      nome: req.usuario!.nome,
    });
    res.status(204).end();
  },
};
