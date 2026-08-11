import { AppError } from "../exceptions/AppError";
import { usuarioRepository } from "../repositories/usuario.repository";
import type { AtualizarAssinaturaInput } from "../dtos/admin.dto";

export const adminService = {
  listarUsuarios(page: number, pageSize: number, busca?: string) {
    return usuarioRepository.listar(page, pageSize, busca);
  },

  async atualizarAssinatura(usuarioId: string, dados: AtualizarAssinaturaInput) {
    const usuario = await usuarioRepository.buscarPorId(usuarioId);
    if (!usuario) {
      throw AppError.naoEncontrado("Usuario");
    }
    return usuarioRepository.atualizarAssinatura(usuarioId, dados);
  },
};
