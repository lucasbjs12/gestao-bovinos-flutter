import { prisma } from "../config/prisma";
import { AppError } from "../exceptions/AppError";
import { atividadeRepository } from "../repositories/atividade.repository";
import { conviteRepository } from "../repositories/convite.repository";
import { membroRepository } from "../repositories/membro.repository";
import { gerarCodigoConvite } from "../utils/codigoConvite";

interface Autor {
  id: string;
  nome: string;
}

function conviteValido(convite: { usado: boolean; expiraEm: Date }): boolean {
  return !convite.usado && convite.expiraEm > new Date();
}

export const conviteService = {
  async gerar(fazendaId: string, autor: Autor) {
    for (let tentativa = 0; tentativa < 5; tentativa += 1) {
      const codigo = gerarCodigoConvite();
      const existente = await conviteRepository.buscarPorCodigo(codigo);
      if (!existente) {
        return conviteRepository.criar({ codigo, fazendaId, criadoPorId: autor.id });
      }
    }
    throw new AppError(500, "codigo_generation_failed", "Nao foi possivel gerar um codigo unico, tente novamente");
  },

  listar(fazendaId: string) {
    return conviteRepository.listarPorFazenda(fazendaId);
  },

  async validar(codigo: string) {
    const convite = await conviteRepository.buscarPorCodigo(codigo);
    if (!convite) {
      throw AppError.naoEncontrado("Convite");
    }
    return { ...convite, valido: conviteValido(convite) };
  },

  async aceitar(codigo: string, usuario: Autor) {
    const convite = await conviteRepository.buscarPorCodigo(codigo);
    if (!convite) {
      throw AppError.naoEncontrado("Convite");
    }
    if (!conviteValido(convite)) {
      throw AppError.conflito("Este convite ja foi usado ou expirou");
    }
    if (convite.fazenda.donoId === usuario.id) {
      throw AppError.conflito("Voce ja e o dono desta fazenda");
    }

    const membroExistente = await membroRepository.buscar(convite.fazendaId, usuario.id);
    if (membroExistente) {
      throw AppError.conflito("Voce ja e membro desta fazenda");
    }

    const membro = await prisma.$transaction(async (tx) => {
      const novoMembro = await tx.membro.create({
        data: {
          fazendaId: convite.fazendaId,
          usuarioId: usuario.id,
          papel: "convidado",
          nome: usuario.nome,
        },
      });
      await tx.convite.update({
        where: { codigo },
        data: { usado: true, usadoPorId: usuario.id },
      });
      return novoMembro;
    });

    await atividadeRepository.registrar({
      fazendaId: convite.fazendaId,
      autorId: usuario.id,
      autorNome: usuario.nome,
      acao: "membro_ingressou",
      descricao: `${usuario.nome} entrou na fazenda "${convite.fazenda.nome}" como convidado`,
    });

    return { membro, fazenda: convite.fazenda };
  },
};
