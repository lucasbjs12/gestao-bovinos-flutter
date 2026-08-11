import { AppError } from "../exceptions/AppError";
import { atividadeRepository } from "../repositories/atividade.repository";
import { eventoSanitarioRepository } from "../repositories/eventoSanitario.repository";
import { invernadaRepository } from "../repositories/invernada.repository";
import type {
  AtualizarEventoSanitarioInput,
  CriarEventoSanitarioInput,
  ListarEventosSanitariosQuery,
} from "../dtos/eventoSanitario.dto";

interface Autor {
  id: string;
  nome: string;
}

async function validarReferencias(fazendaId: string, dados: {
  invernadaId?: string | null;
  bovinoIds?: string[];
}) {
  if (dados.invernadaId) {
    const invernada = await invernadaRepository.buscarPorId(fazendaId, dados.invernadaId);
    if (!invernada) {
      throw AppError.validacao("invernadaId nao pertence a esta fazenda");
    }
  }
  if (dados.bovinoIds && dados.bovinoIds.length > 0) {
    const todosValidos = await eventoSanitarioRepository.validarBovinosDaFazenda(
      fazendaId,
      dados.bovinoIds,
    );
    if (!todosValidos) {
      throw AppError.validacao("Um ou mais bovinoIds nao pertencem a esta fazenda");
    }
  }
}

export const eventoSanitarioService = {
  listar(fazendaId: string, query: ListarEventosSanitariosQuery) {
    return eventoSanitarioRepository.listar(fazendaId, query);
  },

  async buscarPorId(fazendaId: string, id: string) {
    const evento = await eventoSanitarioRepository.buscarPorId(fazendaId, id);
    if (!evento) {
      throw AppError.naoEncontrado("Evento sanitario");
    }
    return evento;
  },

  async criar(fazendaId: string, dados: CriarEventoSanitarioInput, autor: Autor) {
    await validarReferencias(fazendaId, dados);
    const evento = await eventoSanitarioRepository.criar(fazendaId, dados);
    await atividadeRepository.registrar({
      fazendaId,
      autorId: autor.id,
      autorNome: autor.nome,
      acao: "evento_salvo",
      descricao: `Evento sanitario "${evento.tipo}" registrado para ${dados.bovinoIds.length} animal(is)`,
    });
    return evento;
  },

  async atualizar(fazendaId: string, id: string, dados: AtualizarEventoSanitarioInput, autor: Autor) {
    await this.buscarPorId(fazendaId, id);
    await validarReferencias(fazendaId, dados);
    const evento = await eventoSanitarioRepository.atualizar(id, dados);
    await atividadeRepository.registrar({
      fazendaId,
      autorId: autor.id,
      autorNome: autor.nome,
      acao: "evento_salvo",
      descricao: `Evento sanitario "${evento.tipo}" atualizado`,
    });
    return evento;
  },

  async remover(fazendaId: string, id: string, autor: Autor) {
    const evento = await this.buscarPorId(fazendaId, id);
    await eventoSanitarioRepository.remover(id);
    await atividadeRepository.registrar({
      fazendaId,
      autorId: autor.id,
      autorNome: autor.nome,
      acao: "evento_excluido",
      descricao: `Evento sanitario "${evento.tipo}" excluido`,
    });
  },
};
