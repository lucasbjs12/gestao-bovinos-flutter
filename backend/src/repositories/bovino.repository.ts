import { CategoriaBovino, Prisma } from "@prisma/client";
import { prisma } from "../config/prisma";
import type { AtualizarBovinoInput, CriarBovinoInput, RegistrarBaixaInput } from "../dtos/bovino.dto";

const ORDENACAO: Record<string, Prisma.BovinoOrderByWithRelationInput> = {
  brinco: { numeroBrinco: "asc" },
  nome: { nomeAnimal: "asc" },
  categoria: { categoria: "asc" },
  peso: { pesoAtualKg: "desc" },
};

interface FiltrosListagem {
  page: number;
  pageSize: number;
  busca?: string;
  invernadaId?: string;
  categoria?: CategoriaBovino;
  ordenarPor: string;
}

export const bovinoRepository = {
  async listar(fazendaId: string, filtros: FiltrosListagem) {
    const where: Prisma.BovinoWhereInput = {
      fazendaId,
      ...(filtros.invernadaId ? { invernadaId: filtros.invernadaId } : {}),
      ...(filtros.categoria ? { categoria: filtros.categoria } : {}),
      ...(filtros.busca
        ? {
            OR: [
              { numeroBrinco: { contains: filtros.busca, mode: "insensitive" } },
              { nomeAnimal: { contains: filtros.busca, mode: "insensitive" } },
            ],
          }
        : {}),
    };

    const [itens, total] = await Promise.all([
      prisma.bovino.findMany({
        where,
        include: { invernada: { select: { id: true, descricao: true } } },
        orderBy: ORDENACAO[filtros.ordenarPor] ?? ORDENACAO.brinco,
        skip: (filtros.page - 1) * filtros.pageSize,
        take: filtros.pageSize,
      }),
      prisma.bovino.count({ where }),
    ]);

    return { itens, total };
  },

  buscarPorId(fazendaId: string, id: string) {
    return prisma.bovino.findFirst({
      where: { id, fazendaId },
      include: {
        invernada: { select: { id: true, descricao: true } },
        mae: { select: { id: true, numeroBrinco: true, nomeAnimal: true } },
        baixas: { orderBy: { dataBaixa: "desc" } },
      },
    });
  },

  criar(fazendaId: string, dados: CriarBovinoInput) {
    return prisma.bovino.create({ data: { fazendaId, ...dados } });
  },

  atualizar(id: string, dados: AtualizarBovinoInput) {
    return prisma.bovino.update({ where: { id }, data: dados });
  },

  remover(id: string) {
    return prisma.bovino.delete({ where: { id } });
  },

  async registrarBaixa(bovinoId: string, dados: RegistrarBaixaInput) {
    return prisma.$transaction(async (tx) => {
      const baixa = await tx.baixaBovino.create({ data: { bovinoId, ...dados } });
      const bovino = await tx.bovino.update({
        where: { id: bovinoId },
        data: { status: "Baixado" },
      });
      return { baixa, bovino };
    });
  },

  async reativar(bovinoId: string) {
    return prisma.$transaction(async (tx) => {
      const ultimaBaixa = await tx.baixaBovino.findFirst({
        where: { bovinoId },
        orderBy: { dataBaixa: "desc" },
      });
      if (ultimaBaixa) {
        await tx.baixaBovino.delete({ where: { id: ultimaBaixa.id } });
      }
      return tx.bovino.update({
        where: { id: bovinoId },
        data: { status: "Ativo" },
      });
    });
  },
};
