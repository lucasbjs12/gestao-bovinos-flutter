import { Request, Response } from "express";
import { conviteService } from "../services/convite.service";
import { sucesso } from "../utils/respostaPadrao";

export const conviteController = {
  async gerar(req: Request, res: Response) {
    const convite = await conviteService.gerar(req.fazendaAtiva!.id, {
      id: req.usuario!.id,
      nome: req.usuario!.nome,
    });
    sucesso(res, convite, "Convite gerado", 201);
  },

  async listar(req: Request, res: Response) {
    const convites = await conviteService.listar(req.fazendaAtiva!.id);
    sucesso(res, convites);
  },

  async validar(req: Request<{ codigo: string }>, res: Response) {
    const convite = await conviteService.validar(req.params.codigo);
    sucesso(res, convite);
  },

  async aceitar(req: Request<{ codigo: string }>, res: Response) {
    const resultado = await conviteService.aceitar(req.params.codigo, {
      id: req.usuario!.id,
      nome: req.usuario!.nome,
    });
    sucesso(res, resultado, "Convite aceito");
  },
};
