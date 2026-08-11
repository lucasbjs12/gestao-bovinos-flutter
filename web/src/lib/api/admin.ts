import { api } from "../api-client";
import type { Paginacao } from "./invernadas";

export type StatusAssinatura = "pendente" | "ativo" | "bloqueado" | "vencido";

export interface UsuarioAdmin {
  id: string;
  nome: string;
  email: string;
  isAdmin: boolean;
  statusAssinatura: StatusAssinatura;
  plano: string | null;
  vencimento: string | null;
  criadoEm: string;
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
};
