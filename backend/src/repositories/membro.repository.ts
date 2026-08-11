import { Papel } from "@prisma/client";
import { prisma } from "../config/prisma";

export const membroRepository = {
  criar(dados: { fazendaId: string; usuarioId: string; papel: Papel; nome?: string }) {
    return prisma.membro.create({ data: dados });
  },

  buscar(fazendaId: string, usuarioId: string) {
    return prisma.membro.findUnique({
      where: { fazendaId_usuarioId: { fazendaId, usuarioId } },
    });
  },

  listarPorFazenda(fazendaId: string) {
    return prisma.membro.findMany({
      where: { fazendaId },
      include: { usuario: { select: { id: true, nome: true, email: true } } },
      orderBy: { desde: "asc" },
    });
  },

  remover(fazendaId: string, usuarioId: string) {
    return prisma.membro.delete({
      where: { fazendaId_usuarioId: { fazendaId, usuarioId } },
    });
  },
};
