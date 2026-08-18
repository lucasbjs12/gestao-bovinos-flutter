import { api } from "../api-client";
import type { Paginacao } from "./invernadas";

export type CategoriaBovino =
  | "Vaca"
  | "Novilha"
  | "Terneira"
  | "Terneiro"
  | "Novilho"
  | "Touro"
  | "Boi";

export type MotivoBaixa = "Morte" | "Venda" | "Furto" | "Outros";

// Paleta fixa (mesma do backend/app) -- destaque visual manual, ex: novilhas
// vacinadas com produto especial, marcadas em lote na tela de novo evento.
export type CorDestaque =
  | "amarelo"
  | "azul"
  | "verde"
  | "vermelho"
  | "roxo"
  | "laranja";

export interface BaixaBovino {
  id: string;
  bovinoId: string;
  motivo: MotivoBaixa;
  observacoes: string | null;
  dataBaixa: string;
}

export interface Bovino {
  id: string;
  fazendaId: string;
  nomeAnimal: string | null;
  codigoEpc: string | null;
  codigoInterno: string | null;
  numeroBrinco: string;
  raca: string | null;
  dataNascimento: string | null;
  pesoAtualKg: string | null;
  pelagem: string | null;
  categoria: CategoriaBovino;
  status: string;
  origem: string | null;
  observacoes: string | null;
  foto: string | null;
  invernadaId: string | null;
  idMae: string | null;
  estaDeCria: boolean;
  corDestaque: CorDestaque | null;
  rotuloDestaque: string | null;
  atualizadoEm: string;
  invernada?: { id: string; descricao: string } | null;
  mae?: { id: string; numeroBrinco: string; nomeAnimal: string | null } | null;
  baixas?: BaixaBovino[];
}

export interface NovoBovinoInput {
  nomeAnimal?: string | null;
  codigoEpc?: string | null;
  codigoInterno?: string | null;
  numeroBrinco: string;
  raca?: string | null;
  dataNascimento?: string | null;
  pesoAtualKg?: number | null;
  pelagem?: string | null;
  categoria: CategoriaBovino;
  origem?: string | null;
  observacoes?: string | null;
  foto?: string | null;
  invernadaId?: string | null;
  idMae?: string | null;
  estaDeCria?: boolean;
  corDestaque?: CorDestaque | null;
  rotuloDestaque?: string | null;
}

export const bovinosApi = {
  listar: (
    fazendaId: string,
    params?: {
      busca?: string;
      invernadaId?: string;
      categoria?: CategoriaBovino;
      ordenarPor?: "brinco" | "nome" | "categoria" | "peso";
      page?: number;
      pageSize?: number;
    }
  ) => {
    const q = new URLSearchParams();
    if (params?.busca) q.set("busca", params.busca);
    if (params?.invernadaId) q.set("invernadaId", params.invernadaId);
    if (params?.categoria) q.set("categoria", params.categoria);
    if (params?.ordenarPor) q.set("ordenarPor", params.ordenarPor);
    if (params?.page) q.set("page", String(params.page));
    if (params?.pageSize) q.set("pageSize", String(params.pageSize));
    const qs = q.toString();
    return api.get(`/fazendas/${fazendaId}/bovinos${qs ? `?${qs}` : ""}`) as Promise<{
      itens: Bovino[];
      paginacao: Paginacao;
    }>;
  },

  buscarPorId: (fazendaId: string, id: string) =>
    api.get(`/fazendas/${fazendaId}/bovinos/${id}`) as Promise<Bovino>,

  criar: (fazendaId: string, dados: NovoBovinoInput) =>
    api.post(`/fazendas/${fazendaId}/bovinos`, dados) as Promise<Bovino>,

  atualizar: (fazendaId: string, id: string, dados: Partial<NovoBovinoInput>) =>
    api.put(`/fazendas/${fazendaId}/bovinos/${id}`, dados) as Promise<Bovino>,

  darBaixa: (
    fazendaId: string,
    id: string,
    dados: { motivo: MotivoBaixa; observacoes?: string | null; dataBaixa: string }
  ) => api.patch(`/fazendas/${fazendaId}/bovinos/${id}/baixa`, dados) as Promise<Bovino>,

  reativar: (fazendaId: string, id: string) =>
    api.patch(`/fazendas/${fazendaId}/bovinos/${id}/reativar`) as Promise<Bovino>,

  excluir: (fazendaId: string, id: string) => api.delete(`/fazendas/${fazendaId}/bovinos/${id}`),
};
