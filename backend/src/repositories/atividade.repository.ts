import { prisma } from "../config/prisma";

export const atividadeRepository = {
  registrar(dados: {
    fazendaId: string;
    autorId: string;
    autorNome?: string;
    acao: string;
    descricao: string;
  }) {
    return prisma.atividade.create({ data: dados });
  },

  listarPorFazenda(fazendaId: string, page: number, pageSize: number) {
    return prisma.atividade.findMany({
      where: { fazendaId },
      orderBy: { criadoEm: "desc" },
      skip: (page - 1) * pageSize,
      take: pageSize,
    });
  },

  contarPorFazenda(fazendaId: string) {
    return prisma.atividade.count({ where: { fazendaId } });
  },
};
