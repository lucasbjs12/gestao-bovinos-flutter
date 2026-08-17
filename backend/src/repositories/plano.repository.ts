import { prisma } from "../config/prisma";

export const planoRepository = {
  listarAtivos() {
    return prisma.plano.findMany({
      where: { ativo: true },
      orderBy: [{ ordem: "asc" }, { periodicidade: "asc" }],
    });
  },

  buscarPorId(id: string) {
    return prisma.plano.findUnique({ where: { id } });
  },
};
