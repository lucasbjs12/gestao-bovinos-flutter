import { prisma } from "../config/prisma";
import type { CriarMovimentacaoInput } from "../dtos/movimentacao.dto";

export const movimentacaoRepository = {
  async criar(fazendaId: string, dados: CriarMovimentacaoInput) {
    return prisma.$transaction(async (tx) => {
      const bovino = await tx.bovino.findFirst({ where: { id: dados.bovinoId, fazendaId } });
      if (!bovino) {
        return null;
      }

      const movimentacao = await tx.movimentacaoInvernada.create({
        data: {
          fazendaId,
          bovinoId: dados.bovinoId,
          data: dados.data,
          invernadaAnteriorId: bovino.invernadaId,
          novaInvernadaId: dados.novaInvernadaId,
          responsavel: dados.responsavel,
          observacoes: dados.observacoes,
        },
      });

      await tx.bovino.update({
        where: { id: dados.bovinoId },
        data: { invernadaId: dados.novaInvernadaId },
      });

      return movimentacao;
    });
  },
};
