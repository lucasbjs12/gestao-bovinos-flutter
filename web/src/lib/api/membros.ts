import { api } from "../api-client";

export interface Membro {
  fazendaId: string;
  usuarioId: string;
  papel: "dono" | "convidado";
  nome: string | null;
  desde: string;
  usuario: { id: string; nome: string; email: string };
}

export const membrosApi = {
  listar: (fazendaId: string) =>
    api.get(`/fazendas/${fazendaId}/membros`) as Promise<Membro[]>,

  remover: (fazendaId: string, usuarioId: string) =>
    api.delete(`/fazendas/${fazendaId}/membros/${usuarioId}`),
};
