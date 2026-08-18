import { AppError } from "../exceptions/AppError";
import { usuarioRepository } from "../repositories/usuario.repository";
import { assinaturaService } from "./assinatura.service";
import { deletarUsuarioEDados } from "./auth.service";
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

  async ativarPlano(usuarioId: string, planoId: string, proximaCobranca: Date) {
    const usuario = await usuarioRepository.buscarPorId(usuarioId);
    if (!usuario) {
      throw AppError.naoEncontrado("Usuario");
    }
    return assinaturaService.ativarPlanoManual(usuarioId, planoId, proximaCobranca);
  },

  /// [solicitanteId] e quem esta autenticado como admin -- bloqueado de
  /// apagar a propria conta por aqui (sem confirmacao de senha nesse
  /// caminho); quem quiser sair de verdade usa a auto-exclusao normal.
  async removerUsuario(usuarioId: string, solicitanteId: string) {
    if (usuarioId === solicitanteId) {
      throw AppError.validacao("Use a exclusao de conta normal para apagar a propria conta");
    }
    const usuario = await usuarioRepository.buscarPorId(usuarioId);
    if (!usuario) {
      throw AppError.naoEncontrado("Usuario");
    }
    await deletarUsuarioEDados(usuarioId);
  },
};
