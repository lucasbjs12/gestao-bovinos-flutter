import { Prisma } from "@prisma/client";
import { prisma } from "../config/prisma";
import type { CriarInvernadaInput, AtualizarInvernadaInput } from "../dtos/invernada.dto";

export const invernadaRepository = {
  async listar(fazendaId: string, page: number, pageSize: number, busca?: string) {
    const where: Prisma.InvernadaWhereInput = {
      fazendaId,
      ...(busca ? { descricao: { contains: busca, mode: "insensitive" } } : {}),
    };

    const [itens, total] = await Promise.all([
      prisma.invernada.findMany({
        where,
        include: { _count: { select: { bovinos: true } } },
        orderBy: { descricao: "asc" },
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
      prisma.invernada.count({ where }),
    ]);

    return { itens, total };
  },

  buscarPorId(fazendaId: string, id: string) {
    return prisma.invernada.findFirst({
      where: { id, fazendaId },
      include: { _count: { select: { bovinos: true } } },
    });
  },

  criar(fazendaId: string, dados: CriarInvernadaInput) {
    return prisma.invernada.create({ data: { fazendaId, ...dados } });
  },

  atualizar(id: string, dados: AtualizarInvernadaInput) {
    return prisma.invernada.update({ where: { id }, data: dados });
  },

  remover(id: string) {
    return prisma.invernada.delete({ where: { id } });
  },

  listarMovimentacoes(fazendaId: string, invernadaId: string, page: number, pageSize: number) {
    return prisma.movimentacaoInvernada.findMany({
      where: {
        fazendaId,
        OR: [{ invernadaAnteriorId: invernadaId }, { novaInvernadaId: invernadaId }],
      },
      include: {
        bovino: { select: { id: true, numeroBrinco: true, nomeAnimal: true } },
        invernadaAnterior: { select: { id: true, descricao: true } },
        novaInvernada: { select: { id: true, descricao: true } },
      },
      orderBy: { data: "desc" },
      skip: (page - 1) * pageSize,
      take: pageSize,
    });
  },
};
