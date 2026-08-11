import { api } from "../api-client";

export interface NovaMovimentacaoInput {
  bovinoId: string;
  novaInvernadaId: string;
  data: string;
  responsavel?: string | null;
  observacoes?: string | null;
}

export interface Movimentacao {
  id: string;
  fazendaId: string;
  bovinoId: string;
  data: string;
  invernadaAnteriorId: string | null;
  novaInvernadaId: string;
  responsavel: string | null;
  observacoes: string | null;
}

export const movimentacoesApi = {
  criar: (fazendaId: string, dados: NovaMovimentacaoInput) =>
    api.post(`/fazendas/${fazendaId}/movimentacoes`, dados) as Promise<Movimentacao>,
};
