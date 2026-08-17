import { prisma } from "../config/prisma";
import { env } from "../config/env";
import { AppError } from "../exceptions/AppError";
import { usuarioRepository } from "../repositories/usuario.repository";
import { refreshTokenRepository } from "../repositories/refreshToken.repository";
import { passwordResetTokenRepository } from "../repositories/passwordResetToken.repository";
import { verificacaoEmailTokenRepository } from "../repositories/verificacaoEmailToken.repository";
import { emailService } from "./email.service";
import { logger } from "../config/logger";
import { compararSenha, hashSenha } from "../utils/senha";
import {
  calcularExpiracaoRefreshToken,
  calcularExpiracaoResetToken,
  calcularExpiracaoVerificacaoEmail,
  gerarAccessToken,
  gerarRefreshTokenBruto,
  gerarResetTokenBruto,
  hashRefreshToken,
  hashResetToken,
  verificarAccessToken,
} from "../utils/token";
import type { RegistroInput, LoginInput } from "../dtos/auth.dto";

interface TokensGerados {
  accessToken: string;
  refreshToken: string;
}

async function emitirTokens(usuarioId: string, isAdmin: boolean, nome: string): Promise<TokensGerados> {
  const accessToken = gerarAccessToken({ sub: usuarioId, isAdmin, nome });
  const refreshTokenBruto = gerarRefreshTokenBruto();
  await refreshTokenRepository.criar({
    usuarioId,
    tokenHash: hashRefreshToken(refreshTokenBruto),
    expiraEm: calcularExpiracaoRefreshToken(),
  });
  return { accessToken, refreshToken: refreshTokenBruto };
}

export const authService = {
  async registrar(dados: RegistroInput) {
    const existente = await usuarioRepository.buscarPorEmail(dados.email);
    if (existente) {
      throw AppError.conflito("Ja existe uma conta com este e-mail");
    }

    const senhaHash = await hashSenha(dados.senha);

    const { usuario, fazenda } = await prisma.$transaction(async (tx) => {
      const usuarioCriado = await tx.usuario.create({
        data: {
          nome: dados.nome,
          email: dados.email,
          senhaHash,
          // Sem gateway de pagamento integrado ainda: nasce "ativo" para nao bloquear
          // o uso do app. O middleware exigirAssinaturaAtiva ja valida esse campo de
          // verdade, entao ligar cobranca no futuro e so passar a criar como 'pendente'.
          statusAssinatura: "ativo",
        },
      });

      const fazendaCriada = await tx.fazenda.create({
        data: {
          donoId: usuarioCriado.id,
          nome: dados.nomeFazenda?.trim() || `Fazenda de ${dados.nome}`,
        },
      });

      await tx.membro.create({
        data: {
          fazendaId: fazendaCriada.id,
          usuarioId: usuarioCriado.id,
          papel: "dono",
          nome: dados.nome,
        },
      });

      // Plano Gratuito automático -- os 15 animais funcionam como
      // demonstração real do sistema, sem prazo de teste (ver plano de
      // assinaturas).
      await tx.assinatura.create({
        data: { usuarioId: usuarioCriado.id, status: "gratuito", limiteAnimaisAtual: 15 },
      });

      return { usuario: usuarioCriado, fazenda: fazendaCriada };
    });

    const tokens = await emitirTokens(usuario.id, usuario.isAdmin, usuario.nome);

    // Best-effort: se a Resend estiver fora do ar ou sem chave configurada,
    // o cadastro nao pode falhar por causa disso -- so registra o erro.
    try {
      await authService.enviarVerificacaoEmail(usuario);
    } catch (err) {
      logger.error({ err }, "Falha ao enviar e-mail de verificacao no registro");
    }

    return { usuario, fazenda, ...tokens };
  },

  async login(dados: LoginInput) {
    const usuario = await usuarioRepository.buscarPorEmail(dados.email);
    if (!usuario) {
      throw AppError.naoAutorizado("E-mail ou senha invalidos");
    }

    const senhaValida = await compararSenha(dados.senha, usuario.senhaHash);
    if (!senhaValida) {
      throw AppError.naoAutorizado("E-mail ou senha invalidos");
    }

    const tokens = await emitirTokens(usuario.id, usuario.isAdmin, usuario.nome);
    return { usuario, ...tokens };
  },

  async refresh(refreshTokenBruto: string) {
    const tokenHash = hashRefreshToken(refreshTokenBruto);
    const registro = await refreshTokenRepository.buscarPorHash(tokenHash);

    if (!registro || registro.revogadoEm || registro.expiraEm < new Date()) {
      throw AppError.naoAutorizado("Refresh token invalido ou expirado");
    }

    const usuario = await usuarioRepository.buscarPorId(registro.usuarioId);
    if (!usuario) {
      throw AppError.naoAutorizado("Usuario nao encontrado");
    }

    // Rotaciona: revoga o token usado e emite um par novo (accessToken + refreshToken).
    await refreshTokenRepository.revogar(registro.id);
    const tokens = await emitirTokens(usuario.id, usuario.isAdmin, usuario.nome);
    return { usuario, ...tokens };
  },

  async logout(refreshTokenBruto: string) {
    const tokenHash = hashRefreshToken(refreshTokenBruto);
    const registro = await refreshTokenRepository.buscarPorHash(tokenHash);
    if (registro && !registro.revogadoEm) {
      await refreshTokenRepository.revogar(registro.id);
    }
  },

  async esqueciSenha(email: string) {
    const usuario = await usuarioRepository.buscarPorEmail(email);
    // Nao revela se o e-mail existe ou nao (evita enumeracao de contas) --
    // se nao existir, simplesmente nao envia nada e retorna normalmente.
    if (!usuario) return;

    await passwordResetTokenRepository.invalidarTodosDoUsuario(usuario.id);

    const tokenBruto = gerarResetTokenBruto();
    await passwordResetTokenRepository.criar({
      usuarioId: usuario.id,
      tokenHash: hashResetToken(tokenBruto),
      expiraEm: calcularExpiracaoResetToken(),
    });

    const link = `${env.frontendUrl}/redefinir-senha?token=${tokenBruto}`;
    await emailService.enviarResetSenha(usuario.email, usuario.nome, link);
  },

  async redefinirSenha(tokenBruto: string, novaSenha: string) {
    const tokenHash = hashResetToken(tokenBruto);
    const registro = await passwordResetTokenRepository.buscarPorHash(tokenHash);

    if (!registro || registro.usadoEm || registro.expiraEm < new Date()) {
      throw AppError.naoAutorizado("Link de redefinicao invalido ou expirado");
    }

    const senhaHash = await hashSenha(novaSenha);
    await usuarioRepository.atualizarSenha(registro.usuarioId, senhaHash);
    await passwordResetTokenRepository.marcarUsado(registro.id);
    // Revoga todas as sessoes ativas -- redefinir senha derruba logins antigos.
    await refreshTokenRepository.revogarTodosDoUsuario(registro.usuarioId);
  },

  async alterarSenha(usuarioId: string, senhaAtual: string, novaSenha: string) {
    const usuario = await usuarioRepository.buscarPorId(usuarioId);
    if (!usuario) {
      throw AppError.naoAutorizado("Usuario nao encontrado");
    }
    const senhaValida = await compararSenha(senhaAtual, usuario.senhaHash);
    if (!senhaValida) {
      throw AppError.naoAutorizado("Senha atual incorreta");
    }
    const senhaHash = await hashSenha(novaSenha);
    await usuarioRepository.atualizarSenha(usuarioId, senhaHash);
    await refreshTokenRepository.revogarTodosDoUsuario(usuarioId);
  },

  async excluirConta(usuarioId: string, senha: string) {
    const usuario = await usuarioRepository.buscarPorId(usuarioId);
    if (!usuario) {
      throw AppError.naoAutorizado("Usuario nao encontrado");
    }
    const senhaValida = await compararSenha(senha, usuario.senhaHash);
    if (!senhaValida) {
      throw AppError.naoAutorizado("Senha incorreta");
    }

    await prisma.$transaction(async (tx) => {
      // Fazenda(s) proprias cascadeiam invernadas/bovinos/eventos/membros/etc.
      await tx.fazenda.deleteMany({ where: { donoId: usuarioId } });
      // Convites que este usuario criou/usou em fazendas de OUTROS donos nao
      // tem cascade (relacao opcional) -- desvincula antes de apagar o usuario.
      await tx.convite.updateMany({ where: { criadoPorId: usuarioId }, data: { criadoPorId: null } });
      await tx.convite.updateMany({ where: { usadoPorId: usuarioId }, data: { usadoPorId: null } });
      await tx.usuario.delete({ where: { id: usuarioId } });
    });
  },

  async enviarVerificacaoEmail(usuario: { id: string; nome: string; email: string }) {
    await verificacaoEmailTokenRepository.invalidarTodosDoUsuario(usuario.id);

    const tokenBruto = gerarResetTokenBruto();
    await verificacaoEmailTokenRepository.criar({
      usuarioId: usuario.id,
      tokenHash: hashResetToken(tokenBruto),
      expiraEm: calcularExpiracaoVerificacaoEmail(),
    });

    const link = `${env.frontendUrl}/verificar-email?token=${tokenBruto}`;
    await emailService.enviarVerificacaoEmail(usuario.email, usuario.nome, link);
  },

  async reenviarVerificacao(usuarioId: string) {
    const usuario = await usuarioRepository.buscarPorId(usuarioId);
    if (!usuario) {
      throw AppError.naoAutorizado("Usuario nao encontrado");
    }
    if (usuario.emailVerificado) {
      throw AppError.conflito("E-mail ja verificado");
    }
    await authService.enviarVerificacaoEmail(usuario);
  },

  async verificarEmail(tokenBruto: string) {
    const tokenHash = hashResetToken(tokenBruto);
    const registro = await verificacaoEmailTokenRepository.buscarPorHash(tokenHash);

    if (!registro || registro.usadoEm || registro.expiraEm < new Date()) {
      throw AppError.naoAutorizado("Link de verificacao invalido ou expirado");
    }

    await usuarioRepository.marcarEmailVerificado(registro.usuarioId);
    await verificacaoEmailTokenRepository.marcarUsado(registro.id);
  },

  verificarAccessToken,
};
