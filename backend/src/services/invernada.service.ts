import { AppError } from "../exceptions/AppError";
import { atividadeRepository } from "../repositories/atividade.repository";
import { invernadaRepository } from "../repositories/invernada.repository";
import type { AtualizarInvernadaInput, CriarInvernadaInput } from "../dtos/invernada.dto";

interface Autor {
  id: string;
  nome: string;
}

export const invernadaService = {
  listar(fazendaId: string, page: number, pageSize: number, busca?: string) {
    return invernadaRepository.listar(fazendaId, page, pageSize, busca);
  },

  async buscarPorId(fazendaId: string, id: string) {
    const invernada = await invernadaRepository.buscarPorId(fazendaId, id);
    if (!invernada) {
      throw AppError.naoEncontrado("Invernada");
    }
    return invernada;
  },

  async criar(fazendaId: string, dados: CriarInvernadaInput, autor: Autor) {
    const invernada = await invernadaRepository.criar(fazendaId, dados);
    await atividadeRepository.registrar({
      fazendaId,
      autorId: autor.id,
      autorNome: autor.nome,
      acao: "invernada_salva",
      descricao: `Invernada "${invernada.descricao}" criada`,
    });
    return invernada;
  },

  async atualizar(fazendaId: string, id: string, dados: AtualizarInvernadaInput, autor: Autor) {
    await this.buscarPorId(fazendaId, id);
    const invernada = await invernadaRepository.atualizar(id, dados);
    await atividadeRepository.registrar({
      fazendaId,
      autorId: autor.id,
      autorNome: autor.nome,
      acao: "invernada_salva",
      descricao: `Invernada "${invernada.descricao}" atualizada`,
    });
    return invernada;
  },

  async remover(fazendaId: string, id: string, autor: Autor) {
    const invernada = await this.buscarPorId(fazendaId, id);
    await invernadaRepository.remover(id);
    await atividadeRepository.registrar({
      fazendaId,
      autorId: autor.id,
      autorNome: autor.nome,
      acao: "invernada_excluida",
      descricao: `Invernada "${invernada.descricao}" excluida`,
    });
  },

  async listarMovimentacoes(fazendaId: string, invernadaId: string, page: number, pageSize: number) {
    await this.buscarPorId(fazendaId, invernadaId);
    return invernadaRepository.listarMovimentacoes(fazendaId, invernadaId, page, pageSize);
  },
};
