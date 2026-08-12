import { prisma } from "../config/prisma";

export const verificacaoEmailTokenRepository = {
  criar(dados: { usuarioId: string; tokenHash: string; expiraEm: Date }) {
    return prisma.verificacaoEmailToken.create({ data: dados });
  },

  buscarPorHash(tokenHash: string) {
    return prisma.verificacaoEmailToken.findFirst({ where: { tokenHash } });
  },

  marcarUsado(id: string) {
    return prisma.verificacaoEmailToken.update({
      where: { id },
      data: { usadoEm: new Date() },
    });
  },

  invalidarTodosDoUsuario(usuarioId: string) {
    return prisma.verificacaoEmailToken.updateMany({
      where: { usuarioId, usadoEm: null },
      data: { usadoEm: new Date() },
    });
  },
};
