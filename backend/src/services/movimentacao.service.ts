import { AppError } from "../exceptions/AppError";
import { atividadeRepository } from "../repositories/atividade.repository";
import { invernadaRepository } from "../repositories/invernada.repository";
import { movimentacaoRepository } from "../repositories/movimentacao.repository";
import type { CriarMovimentacaoInput } from "../dtos/movimentacao.dto";

interface Autor {
  id: string;
  nome: string;
}

export const movimentacaoService = {
  async criar(fazendaId: string, dados: CriarMovimentacaoInput, autor: Autor) {
    const novaInvernada = await invernadaRepository.buscarPorId(fazendaId, dados.novaInvernadaId);
    if (!novaInvernada) {
      throw AppError.validacao("novaInvernadaId nao pertence a esta fazenda");
    }

    const movimentacao = await movimentacaoRepository.criar(fazendaId, dados);
    if (!movimentacao) {
      throw AppError.naoEncontrado("Bovino");
    }

    await atividadeRepository.registrar({
      fazendaId,
      autorId: autor.id,
      autorNome: autor.nome,
      acao: "movimentacao",
      descricao: `Animal movido para a invernada "${novaInvernada.descricao}"`,
    });

    return movimentacao;
  },
};
