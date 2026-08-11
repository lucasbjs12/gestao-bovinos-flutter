import { prisma } from "../config/prisma";

export const passwordResetTokenRepository = {
  criar(dados: { usuarioId: string; tokenHash: string; expiraEm: Date }) {
    return prisma.passwordResetToken.create({ data: dados });
  },

  buscarPorHash(tokenHash: string) {
    return prisma.passwordResetToken.findFirst({ where: { tokenHash } });
  },

  marcarUsado(id: string) {
    return prisma.passwordResetToken.update({
      where: { id },
      data: { usadoEm: new Date() },
    });
  },

  invalidarTodosDoUsuario(usuarioId: string) {
    return prisma.passwordResetToken.updateMany({
      where: { usuarioId, usadoEm: null },
      data: { usadoEm: new Date() },
    });
  },
};
