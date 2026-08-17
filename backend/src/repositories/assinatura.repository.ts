import { Prisma, StatusPlano } from "@prisma/client";
import { prisma } from "../config/prisma";

export const assinaturaRepository = {
  buscarPorUsuarioId(usuarioId: string) {
    return prisma.assinatura.findUnique({
      where: { usuarioId },
      include: { plano: true },
    });
  },

  criarGratuita(usuarioId: string) {
    return prisma.assinatura.create({
      data: { usuarioId, status: StatusPlano.gratuito, limiteAnimaisAtual: 15 },
      include: { plano: true },
    });
  },

  atualizar(usuarioId: string, dados: Prisma.AssinaturaUncheckedUpdateInput) {
    return prisma.assinatura.update({
      where: { usuarioId },
      data: dados,
      include: { plano: true },
    });
  },

  buscarPorPreapprovalId(preapprovalId: string) {
    return prisma.assinatura.findUnique({
      where: { mercadoPagoPreapprovalId: preapprovalId },
      include: { plano: true },
    });
  },
};
