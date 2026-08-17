import { Prisma, StatusAssinatura } from "@prisma/client";
import { prisma } from "../config/prisma";

export const usuarioRepository = {
  buscarPorEmail(email: string) {
    return prisma.usuario.findUnique({ where: { email } });
  },

  buscarPorId(id: string) {
    return prisma.usuario.findUnique({ where: { id } });
  },

  criar(dados: { nome: string; email: string; senhaHash: string }) {
    return prisma.usuario.create({ data: dados });
  },

  async listar(page: number, pageSize: number, busca?: string) {
    const where: Prisma.UsuarioWhereInput = busca
      ? {
          OR: [
            { nome: { contains: busca, mode: "insensitive" } },
            { email: { contains: busca, mode: "insensitive" } },
          ],
        }
      : {};

    const [itens, total] = await Promise.all([
      prisma.usuario.findMany({
        where,
        include: { assinatura: { include: { plano: true } } },
        orderBy: { criadoEm: "desc" },
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
      prisma.usuario.count({ where }),
    ]);

    return { itens, total };
  },

  atualizarAssinatura(
    id: string,
    dados: { statusAssinatura: StatusAssinatura; plano?: string; vencimento?: Date },
  ) {
    return prisma.usuario.update({ where: { id }, data: dados });
  },

  atualizarSenha(id: string, senhaHash: string) {
    return prisma.usuario.update({ where: { id }, data: { senhaHash } });
  },

  marcarEmailVerificado(id: string) {
    return prisma.usuario.update({ where: { id }, data: { emailVerificado: true } });
  },
};
