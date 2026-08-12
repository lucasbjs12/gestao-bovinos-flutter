import { Request, Response } from "express";
import { authService } from "../services/auth.service";
import { usuarioRepository } from "../repositories/usuario.repository";
import { fazendaRepository } from "../repositories/fazenda.repository";
import { AppError } from "../exceptions/AppError";
import { sucesso } from "../utils/respostaPadrao";
import type {
  AlterarSenhaInput,
  EsqueciSenhaInput,
  ExcluirContaInput,
  LoginInput,
  RedefinirSenhaInput,
  RefreshInput,
  RegistroInput,
  VerificarEmailInput,
} from "../dtos/auth.dto";

function usuarioPublico(usuario: {
  id: string;
  nome: string;
  email: string;
  isAdmin: boolean;
  emailVerificado: boolean;
  statusAssinatura: string;
}) {
  return {
    id: usuario.id,
    nome: usuario.nome,
    email: usuario.email,
    isAdmin: usuario.isAdmin,
    emailVerificado: usuario.emailVerificado,
    statusAssinatura: usuario.statusAssinatura,
  };
}

export const authController = {
  async registrar(req: Request<unknown, unknown, RegistroInput>, res: Response) {
    const { usuario, fazenda, accessToken, refreshToken } = await authService.registrar(req.body);
    sucesso(
      res,
      { usuario: usuarioPublico(usuario), fazenda, accessToken, refreshToken },
      "Conta criada com sucesso",
      201,
    );
  },

  async login(req: Request<unknown, unknown, LoginInput>, res: Response) {
    const { usuario, accessToken, refreshToken } = await authService.login(req.body);
    sucesso(res, { usuario: usuarioPublico(usuario), accessToken, refreshToken }, "Login realizado");
  },

  async refresh(req: Request<unknown, unknown, RefreshInput>, res: Response) {
    const { usuario, accessToken, refreshToken } = await authService.refresh(req.body.refreshToken);
    sucesso(res, { usuario: usuarioPublico(usuario), accessToken, refreshToken }, "Token renovado");
  },

  async logout(req: Request<unknown, unknown, RefreshInput>, res: Response) {
    await authService.logout(req.body.refreshToken);
    sucesso(res, null, "Logout realizado");
  },

  async me(req: Request, res: Response) {
    const usuario = await usuarioRepository.buscarPorId(req.usuario!.id);
    if (!usuario) {
      throw AppError.naoEncontrado("Usuario");
    }
    const fazenda = await fazendaRepository.buscarPorDono(usuario.id);
    sucesso(res, { usuario: usuarioPublico(usuario), fazendaPropria: fazenda });
  },

  async esqueciSenha(req: Request<unknown, unknown, EsqueciSenhaInput>, res: Response) {
    await authService.esqueciSenha(req.body.email);
    sucesso(res, null, "Se o e-mail existir, um link de redefinicao foi enviado");
  },

  async redefinirSenha(req: Request<unknown, unknown, RedefinirSenhaInput>, res: Response) {
    await authService.redefinirSenha(req.body.token, req.body.novaSenha);
    sucesso(res, null, "Senha redefinida com sucesso");
  },

  async alterarSenha(req: Request<unknown, unknown, AlterarSenhaInput>, res: Response) {
    await authService.alterarSenha(req.usuario!.id, req.body.senhaAtual, req.body.novaSenha);
    sucesso(res, null, "Senha alterada com sucesso");
  },

  async excluirConta(req: Request<unknown, unknown, ExcluirContaInput>, res: Response) {
    await authService.excluirConta(req.usuario!.id, req.body.senha);
    sucesso(res, null, "Conta excluida com sucesso");
  },

  async verificarEmail(req: Request<unknown, unknown, VerificarEmailInput>, res: Response) {
    await authService.verificarEmail(req.body.token);
    sucesso(res, null, "E-mail verificado com sucesso");
  },

  async reenviarVerificacao(req: Request, res: Response) {
    await authService.reenviarVerificacao(req.usuario!.id);
    sucesso(res, null, "E-mail de verificacao reenviado");
  },
};
