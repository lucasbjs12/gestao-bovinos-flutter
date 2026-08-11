import { Request, Response } from "express";
import { membroService } from "../services/membro.service";
import { sucesso } from "../utils/respostaPadrao";

export const membroController = {
  async listar(req: Request, res: Response) {
    const membros = await membroService.listar(req.fazendaAtiva!.id);
    sucesso(res, membros);
  },

  async remover(req: Request<{ usuarioId: string }>, res: Response) {
    await membroService.remover(req.fazendaAtiva!.id, req.params.usuarioId, {
      id: req.usuario!.id,
      nome: req.usuario!.nome,
    });
    res.status(204).end();
  },
};
