import { Request, Response } from "express";
import { adminService } from "../services/admin.service";
import { sucesso } from "../utils/respostaPadrao";
import { respostaPaginada } from "../utils/paginacaoResposta";
import type { AtualizarAssinaturaInput, ListarUsuariosQuery } from "../dtos/admin.dto";

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
};
