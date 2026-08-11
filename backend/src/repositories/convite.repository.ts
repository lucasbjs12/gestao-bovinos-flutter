import { prisma } from "../config/prisma";

const CONVITE_VALIDADE_HORAS = 48;

export const conviteRepository = {
  buscarPorCodigo(codigo: string) {
    return prisma.convite.findUnique({
      where: { codigo },
      include: { fazenda: { select: { id: true, nome: true, donoId: true } } },
    });
  },

  criar(dados: { codigo: string; fazendaId: string; criadoPorId: string }) {
    return prisma.convite.create({
      data: {
        codigo: dados.codigo,
        fazendaId: dados.fazendaId,
        criadoPorId: dados.criadoPorId,
        papel: "convidado",
        expiraEm: new Date(Date.now() + CONVITE_VALIDADE_HORAS * 60 * 60 * 1000),
      },
    });
  },

  marcarUsado(codigo: string, usadoPorId: string) {
    return prisma.convite.update({
      where: { codigo },
      data: { usado: true, usadoPorId },
    });
  },

  listarPorFazenda(fazendaId: string) {
    return prisma.convite.findMany({
      where: { fazendaId },
      orderBy: { criadoEm: "desc" },
    });
  },
};
