import { Prisma } from "@prisma/client";
import { prisma } from "../config/prisma";
import type {
  AtualizarEventoSanitarioInput,
  CriarEventoSanitarioInput,
  ListarEventosSanitariosQuery,
} from "../dtos/eventoSanitario.dto";

export const eventoSanitarioRepository = {
  async listar(fazendaId: string, query: ListarEventosSanitariosQuery) {
    const where: Prisma.EventoSanitarioWhereInput = {
      fazendaId,
      ...(query.tipo ? { tipo: query.tipo } : {}),
      ...(query.invernadaId ? { invernadaId: query.invernadaId } : {}),
      ...(query.busca
        ? {
            OR: [
              { produtoUtilizado: { contains: query.busca, mode: "insensitive" } },
              { responsavel: { contains: query.busca, mode: "insensitive" } },
              { observacoes: { contains: query.busca, mode: "insensitive" } },
            ],
          }
        : {}),
    };

    const [itens, total] = await Promise.all([
      prisma.eventoSanitario.findMany({
        where,
        include: {
          invernada: { select: { id: true, descricao: true } },
          bovinos: { include: { bovino: { select: { id: true, numeroBrinco: true, nomeAnimal: true } } } },
        },
        orderBy: { dataEvento: "desc" },
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
      }),
      prisma.eventoSanitario.count({ where }),
    ]);

    return { itens, total };
  },

  buscarPorId(fazendaId: string, id: string) {
    return prisma.eventoSanitario.findFirst({
      where: { id, fazendaId },
      include: {
        invernada: { select: { id: true, descricao: true } },
        bovinos: { include: { bovino: { select: { id: true, numeroBrinco: true, nomeAnimal: true } } } },
      },
    });
  },

  criar(fazendaId: string, dados: CriarEventoSanitarioInput) {
    const { bovinoIds, ...resto } = dados;
    return prisma.eventoSanitario.create({
      data: {
        fazendaId,
        ...resto,
        bovinos: { createMany: { data: bovinoIds.map((bovinoId) => ({ bovinoId })) } },
      },
      include: { bovinos: true },
    });
  },

  async atualizar(id: string, dados: AtualizarEventoSanitarioInput) {
    const { bovinoIds, ...resto } = dados;
    return prisma.$transaction(async (tx) => {
      if (bovinoIds) {
        await tx.eventoSanitarioBovino.deleteMany({ where: { eventoId: id } });
        await tx.eventoSanitarioBovino.createMany({
          data: bovinoIds.map((bovinoId) => ({ eventoId: id, bovinoId })),
        });
      }
      return tx.eventoSanitario.update({
        where: { id },
        data: resto,
        include: { bovinos: true },
      });
    });
  },

  remover(id: string) {
    return prisma.eventoSanitario.delete({ where: { id } });
  },

  async validarBovinosDaFazenda(fazendaId: string, bovinoIds: string[]): Promise<boolean> {
    const total = await prisma.bovino.count({ where: { id: { in: bovinoIds }, fazendaId } });
    return total === bovinoIds.length;
  },
};
