import { api } from "../api-client";

export interface Invernada {
  id: string;
  fazendaId: string;
  descricao: string;
  hectares: string | null;
  urlFoto: string | null;
  observacoes: string | null;
  atualizadoEm: string;
  _count?: { bovinos: number };
}

export interface Paginacao {
  page: number;
  pageSize: number;
  total: number;
  totalPaginas: number;
}

export interface MovimentacaoInvernada {
  id: string;
  fazendaId: string;
  bovinoId: string;
  data: string;
  invernadaAnteriorId: string | null;
  novaInvernadaId: string;
  responsavel: string | null;
  observacoes: string | null;
  bovino: { id: string; numeroBrinco: string; nomeAnimal: string | null };
  invernadaAnterior: { id: string; descricao: string } | null;
  novaInvernada: { id: string; descricao: string };
}

export interface NovoInvernadaInput {
  descricao: string;
  hectares?: number | null;
  urlFoto?: string | null;
  observacoes?: string | null;
}

export const invernadasApi = {
  listar: (fazendaId: string, params?: { busca?: string; page?: number; pageSize?: number }) => {
    const q = new URLSearchParams();
    if (params?.busca) q.set("busca", params.busca);
    if (params?.page) q.set("page", String(params.page));
    if (params?.pageSize) q.set("pageSize", String(params.pageSize));
    const qs = q.toString();
    return api.get(`/fazendas/${fazendaId}/invernadas${qs ? `?${qs}` : ""}`) as Promise<{
      itens: Invernada[];
      paginacao: Paginacao;
    }>;
  },

  buscarPorId: (fazendaId: string, id: string) =>
    api.get(`/fazendas/${fazendaId}/invernadas/${id}`) as Promise<Invernada>,

  criar: (fazendaId: string, dados: NovoInvernadaInput) =>
    api.post(`/fazendas/${fazendaId}/invernadas`, dados) as Promise<Invernada>,

  atualizar: (fazendaId: string, id: string, dados: Partial<NovoInvernadaInput>) =>
    api.put(`/fazendas/${fazendaId}/invernadas/${id}`, dados) as Promise<Invernada>,

  excluir: (fazendaId: string, id: string) => api.delete(`/fazendas/${fazendaId}/invernadas/${id}`),

  movimentacoes: (fazendaId: string, id: string) =>
    api.get(`/fazendas/${fazendaId}/invernadas/${id}/movimentacoes`) as Promise<
      MovimentacaoInvernada[]
    >,
};
