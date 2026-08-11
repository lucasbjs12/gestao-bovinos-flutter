import { prisma } from "../config/prisma";

export const refreshTokenRepository = {
  criar(dados: { usuarioId: string; tokenHash: string; expiraEm: Date }) {
    return prisma.refreshToken.create({ data: dados });
  },

  buscarPorHash(tokenHash: string) {
    return prisma.refreshToken.findFirst({ where: { tokenHash } });
  },

  revogar(id: string) {
    return prisma.refreshToken.update({
      where: { id },
      data: { revogadoEm: new Date() },
    });
  },

  revogarTodosDoUsuario(usuarioId: string) {
    return prisma.refreshToken.updateMany({
      where: { usuarioId, revogadoEm: null },
      data: { revogadoEm: new Date() },
    });
  },
};
