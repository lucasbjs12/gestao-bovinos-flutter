import { prisma } from "../../src/config/prisma";

/** Ordem respeita as FKs: filhos antes dos pais. */
export async function limparBanco(): Promise<void> {
  await prisma.$transaction([
    prisma.refreshToken.deleteMany(),
    prisma.atividade.deleteMany(),
    prisma.eventoSanitarioBovino.deleteMany(),
    prisma.eventoSanitario.deleteMany(),
    prisma.movimentacaoInvernada.deleteMany(),
    prisma.baixaBovino.deleteMany(),
    prisma.bovino.deleteMany(),
    prisma.invernada.deleteMany(),
    prisma.convite.deleteMany(),
    prisma.membro.deleteMany(),
    prisma.fazenda.deleteMany(),
    prisma.usuario.deleteMany(),
  ]);
}
