import { prisma } from "../config/prisma";

export const fazendaRepository = {
  criar(dados: { donoId: string; nome: string }) {
    return prisma.fazenda.create({ data: dados });
  },

  buscarPorDono(donoId: string) {
    return prisma.fazenda.findFirst({ where: { donoId } });
  },

  buscarPorId(id: string) {
    return prisma.fazenda.findUnique({ where: { id } });
  },

  atualizar(id: string, dados: { nome: string }) {
    return prisma.fazenda.update({ where: { id }, data: dados });
  },
};
