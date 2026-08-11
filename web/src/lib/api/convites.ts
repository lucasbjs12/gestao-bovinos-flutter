import { api } from "../api-client";

export interface Convite {
  codigo: string;
  fazendaId: string;
  papel: "dono" | "convidado";
  criadoPorId: string | null;
  criadoEm: string;
  expiraEm: string;
  usado: boolean;
  usadoPorId: string | null;
}

export const convitesApi = {
  listar: (fazendaId: string) =>
    api.get(`/fazendas/${fazendaId}/convites`) as Promise<Convite[]>,

  gerar: (fazendaId: string) =>
    api.post(`/fazendas/${fazendaId}/convites`) as Promise<Convite>,

  aceitar: (codigo: string) =>
    api.post(`/convites/${codigo.trim().toUpperCase()}/aceitar`) as Promise<{
      membro: { fazendaId: string; usuarioId: string; papel: string; nome: string | null };
      fazenda: { id: string; nome: string; donoId: string };
    }>,
};
