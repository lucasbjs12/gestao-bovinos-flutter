import { Request, Response } from "express";
import { adminService } from "../services/admin.service";
import { sucesso } from "../utils/respostaPadrao";
import { respostaPaginada } from "../utils/paginacaoResposta";
import type {
  AtivarPlanoManualInput,
  AtualizarAssinaturaInput,
  ListarUsuariosQuery,
} from "../dtos/admin.dto";

function usuarioSemSenha(usuario: Record<string, unknown> & { senhaHash?: unknown }) {
  const { senhaHash: _senhaHash, ...resto } = usuario;
  return resto;
}

export const adminController = {
  async listarUsuarios(req: Request, res: Response) {
    const { page, pageSize, busca } = req.query as unknown as ListarUsuariosQuery;
    const { itens, total } = await adminService.listarUsuarios(page, pageSize, busca);
    sucesso(res, respostaPaginada(itens.map(usuarioSemSenha), total, page, pageSize));
  },

  async atualizarAssinatura(
    req: Request<{ id: string }, unknown, AtualizarAssinaturaInput>,
    res: Response,
  ) {
    const usuario = await adminService.atualizarAssinatura(req.params.id, req.body);
    sucesso(res, usuarioSemSenha(usuario), "Assinatura atualizada");
  },

  async ativarPlano(
    req: Request<{ id: string }, unknown, AtivarPlanoManualInput>,
    res: Response,
  ) {
    const assinatura = await adminService.ativarPlano(
      req.params.id,
      req.body.planoId,
      req.body.proximaCobranca,
    );
    sucesso(res, assinatura, "Plano ativado");
  },

  async removerUsuario(req: Request<{ id: string }>, res: Response) {
    await adminService.removerUsuario(req.params.id, req.usuario!.id);
    res.status(204).end();
  },
};
