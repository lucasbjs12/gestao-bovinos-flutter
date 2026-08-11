import { AppError } from "../exceptions/AppError";
import { atividadeRepository } from "../repositories/atividade.repository";
import { membroRepository } from "../repositories/membro.repository";

interface Autor {
  id: string;
  nome: string;
}

export const membroService = {
  listar(fazendaId: string) {
    return membroRepository.listarPorFazenda(fazendaId);
  },

  async remover(fazendaId: string, usuarioId: string, autor: Autor) {
    const membro = await membroRepository.buscar(fazendaId, usuarioId);
    if (!membro) {
      throw AppError.naoEncontrado("Membro");
    }
    if (membro.papel === "dono") {
      throw AppError.proibido("O dono da fazenda nao pode ser removido");
    }

    await membroRepository.remover(fazendaId, usuarioId);
    await atividadeRepository.registrar({
      fazendaId,
      autorId: autor.id,
      autorNome: autor.nome,
      acao: "membro_removido",
      descricao: `${membro.nome ?? "Um membro"} foi removido da fazenda`,
    });
  },
};
