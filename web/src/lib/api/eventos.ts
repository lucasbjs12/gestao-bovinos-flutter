import { api } from "../api-client";
import type { Paginacao } from "./invernadas";

export type TipoEventoSanitario =
  | "Vacinacao"
  | "Vermifugacao"
  | "Medicacao"
  | "Castracao"
  | "Banho"
  | "Outros";

export interface EventoSanitario {
  id: string;
  fazendaId: string;
  tipo: TipoEventoSanitario;
  dataEvento: string | null;
  invernadaId: string | null;
  produtoUtilizado: string | null;
  dosagem: string | null;
  responsavel: string | null;
  observacoes: string | null;
  invernada?: { id: string; descricao: string } | null;
  bovinos: Array<{
    eventoId: string;
    bovinoId: string;
    bovino?: { id: string; numeroBrinco: string; nomeAnimal: string | null };
  }>;
}

export interface NovoEventoInput {
  tipo: TipoEventoSanitario;
  dataEvento?: string | null;
  invernadaId?: string | null;
  produtoUtilizado?: string | null;
  dosagem?: string | null;
  responsavel?: string | null;
  observacoes?: string | null;
  bovinoIds: string[];
}

export const eventosApi = {
  listar: (
    fazendaId: string,
    params?: { busca?: string; tipo?: TipoEventoSanitario; invernadaId?: string; page?: number; pageSize?: number }
  ) => {
    const q = new URLSearchParams();
    if (params?.busca) q.set("busca", params.busca);
    if (params?.tipo) q.set("tipo", params.tipo);
    if (params?.invernadaId) q.set("invernadaId", params.invernadaId);
    if (params?.page) q.set("page", String(params.page));
    if (params?.pageSize) q.set("pageSize", String(params.pageSize));
    const qs = q.toString();
    return api.get(`/fazendas/${fazendaId}/eventos-sanitarios${qs ? `?${qs}` : ""}`) as Promise<{
      itens: EventoSanitario[];
      paginacao: Paginacao;
    }>;
  },

  buscarPorId: (fazendaId: string, id: string) =>
    api.get(`/fazendas/${fazendaId}/eventos-sanitarios/${id}`) as Promise<EventoSanitario>,

  criar: (fazendaId: string, dados: NovoEventoInput) =>
    api.post(`/fazendas/${fazendaId}/eventos-sanitarios`, dados) as Promise<EventoSanitario>,

  atualizar: (fazendaId: string, id: string, dados: Partial<NovoEventoInput>) =>
    api.put(`/fazendas/${fazendaId}/eventos-sanitarios/${id}`, dados) as Promise<EventoSanitario>,

  excluir: (fazendaId: string, id: string) =>
    api.delete(`/fazendas/${fazendaId}/eventos-sanitarios/${id}`),
};
