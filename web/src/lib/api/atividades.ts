import { api } from "../api-client";
import type { Paginacao } from "./invernadas";

export interface Atividade {
  id: string;
  fazendaId: string;
  autorId: string;
  autorNome: string | null;
  acao: string;
  descricao: string;
  criadoEm: string;
}

export const atividadesApi = {
  listar: (fazendaId: string, params?: { page?: number; pageSize?: number }) => {
    const q = new URLSearchParams();
    if (params?.page) q.set("page", String(params.page));
    if (params?.pageSize) q.set("pageSize", String(params.pageSize));
    const qs = q.toString();
    return api.get(`/fazendas/${fazendaId}/atividades${qs ? `?${qs}` : ""}`) as Promise<{
      itens: Atividade[];
      paginacao: Paginacao;
    }>;
  },
};
