import { api } from "../api-client";
import type { Paginacao } from "./invernadas";
import type { Plano as PlanoAssinatura, StatusPlano } from "./planos";

export type StatusAssinatura = "pendente" | "ativo" | "bloqueado" | "vencido";

export interface AssinaturaAdmin {
  status: StatusPlano;
  limiteAnimaisAtual: number | null;
  proximaCobranca: string | null;
  plano: PlanoAssinatura | null;
}

export interface UsuarioAdmin {
  id: string;
  nome: string;
  email: string;
  isAdmin: boolean;
  statusAssinatura: StatusAssinatura;
  plano: string | null;
  vencimento: string | null;
  criadoEm: string;
  /// Assinatura do sistema novo (planos configuráveis) -- distinta dos
  /// campos acima, que são do bloqueio de conta antigo.
  assinatura: AssinaturaAdmin | null;
}

export const adminApi = {
  listarUsuarios: (params?: { busca?: string; page?: number; pageSize?: number }) => {
    const q = new URLSearchParams();
    if (params?.busca) q.set("busca", params.busca);
    if (params?.page) q.set("page", String(params.page));
    if (params?.pageSize) q.set("pageSize", String(params.pageSize));
    const qs = q.toString();
    return api.get(`/admin/usuarios${qs ? `?${qs}` : ""}`) as Promise<{
      itens: UsuarioAdmin[];
      paginacao: Paginacao;
    }>;
  },

  atualizarAssinatura: (
    id: string,
    dados: { statusAssinatura: StatusAssinatura; plano?: string; vencimento?: string }
  ) => api.patch(`/admin/usuarios/${id}/assinatura`, dados) as Promise<UsuarioAdmin>,

  ativarPlano: (id: string, dados: { planoId: string; proximaCobranca: string }) =>
    api.post(`/admin/usuarios/${id}/assinatura/ativar-plano`, dados) as Promise<AssinaturaAdmin>,

  removerUsuario: (id: string) => api.delete(`/admin/usuarios/${id}`),
};
