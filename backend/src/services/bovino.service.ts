import { AppError } from "../exceptions/AppError";
import { atividadeRepository } from "../repositories/atividade.repository";
import { bovinoRepository } from "../repositories/bovino.repository";
import { invernadaRepository } from "../repositories/invernada.repository";
import type {
  AtualizarBovinoInput,
  CriarBovinoInput,
  ListarBovinosQuery,
  RegistrarBaixaInput,
} from "../dtos/bovino.dto";

interface Autor {
  id: string;
  nome: string;
}

async function validarReferencias(
  fazendaId: string,
  dados: Partial<CriarBovinoInput>,
  bovinoAtualId?: string,
) {
  if (dados.invernadaId) {
    const invernada = await invernadaRepository.buscarPorId(fazendaId, dados.invernadaId);
    if (!invernada) {
      throw AppError.validacao("invernadaId nao pertence a esta fazenda");
    }
  }
  if (dados.idMae) {
    if (dados.idMae === bovinoAtualId) {
      throw AppError.validacao("Um animal nao pode ser mae de si mesmo");
    }
    const mae = await bovinoRepository.buscarPorId(fazendaId, dados.idMae);
    if (!mae) {
      throw AppError.validacao("idMae nao pertence a esta fazenda");
    }
  }
}

export const bovinoService = {
  listar(fazendaId: string, query: ListarBovinosQuery) {
    return bovinoRepository.listar(fazendaId, query);
  },

  async buscarPorId(fazendaId: string, id: string) {
    const bovino = await bovinoRepository.buscarPorId(fazendaId, id);
    if (!bovino) {
      throw AppError.naoEncontrado("Bovino");
    }
    return bovino;
  },

  async criar(fazendaId: string, dados: CriarBovinoInput, autor: Autor) {
    await validarReferencias(fazendaId, dados);
    const bovino = await bovinoRepository.criar(fazendaId, dados);
    await atividadeRepository.registrar({
      fazendaId,
      autorId: autor.id,
      autorNome: autor.nome,
      acao: "bovino_salvo",
      descricao: `Bovino "${bovino.numeroBrinco}" cadastrado`,
    });
    return bovino;
  },

  async atualizar(fazendaId: string, id: string, dados: AtualizarBovinoInput, autor: Autor) {
    await this.buscarPorId(fazendaId, id);
    await validarReferencias(fazendaId, dados, id);
    const bovino = await bovinoRepository.atualizar(id, dados);
    await atividadeRepository.registrar({
      fazendaId,
      autorId: autor.id,
      autorNome: autor.nome,
      acao: "bovino_salvo",
      descricao: `Bovino "${bovino.numeroBrinco}" atualizado`,
    });
    return bovino;
  },

  async remover(fazendaId: string, id: string, autor: Autor) {
    const bovino = await this.buscarPorId(fazendaId, id);
    await bovinoRepository.remover(id);
    await atividadeRepository.registrar({
      fazendaId,
      autorId: autor.id,
      autorNome: autor.nome,
      acao: "bovino_excluido",
      descricao: `Bovino "${bovino.numeroBrinco}" excluido`,
    });
  },

  async registrarBaixa(fazendaId: string, id: string, dados: RegistrarBaixaInput, autor: Autor) {
    const bovinoAtual = await this.buscarPorId(fazendaId, id);
    if (bovinoAtual.status === "Baixado") {
      throw AppError.conflito("Este animal ja esta baixado");
    }
    const { bovino } = await bovinoRepository.registrarBaixa(id, dados);
    await atividadeRepository.registrar({
      fazendaId,
      autorId: autor.id,
      autorNome: autor.nome,
      acao: "bovino_baixado",
      descricao: `Bovino "${bovino.numeroBrinco}" baixado (${dados.motivo})`,
    });
    return bovino;
  },

  async reativar(fazendaId: string, id: string, autor: Autor) {
    const bovinoAtual = await this.buscarPorId(fazendaId, id);
    if (bovinoAtual.status !== "Baixado") {
      throw AppError.conflito("Este animal nao esta baixado");
    }
    const bovino = await bovinoRepository.reativar(id);
    await atividadeRepository.registrar({
      fazendaId,
      autorId: autor.id,
      autorNome: autor.nome,
      acao: "bovino_reativado",
      descricao: `Bovino "${bovino.numeroBrinco}" reativado`,
    });
    return bovino;
  },
};
