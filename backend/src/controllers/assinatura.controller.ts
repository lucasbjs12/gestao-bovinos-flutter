import { Request, Response } from "express";
import { assinaturaService } from "../services/assinatura.service";
import { sucesso } from "../utils/respostaPadrao";
import type { IniciarCheckoutInput } from "../dtos/assinatura.dto";

export const assinaturaController = {
  async obter(req: Request, res: Response) {
    const { assinatura, contagemAnimais } = await assinaturaService.obterParaFazenda(
      req.fazendaAtiva!.id,
      req.fazendaAtiva!.donoId,
    );
    sucesso(res, { ...assinatura, contagemAnimais });
  },

  async checkout(req: Request<unknown, unknown, IniciarCheckoutInput>, res: Response) {
    const resultado = await assinaturaService.iniciarCheckout(req.usuario!.id, req.body.planoId);
    sucesso(res, resultado);
  },

  async cancelar(req: Request, res: Response) {
    const assinatura = await assinaturaService.cancelar(req.usuario!.id);
    sucesso(res, assinatura, "Assinatura cancelada");
  },
};
