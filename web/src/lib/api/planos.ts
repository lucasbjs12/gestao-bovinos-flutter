import { api } from "../api-client";

export type PeriodicidadePlano = "mensal" | "anual";
export type StatusPlano = "gratuito" | "pendente" | "ativo" | "vencido" | "cancelado";

export interface Plano {
  id: string;
  slug: string;
  nome: string;
  descricao: string | null;
  periodicidade: PeriodicidadePlano;
  valorCentavos: number;
  limiteAnimais: number | null; // null = ilimitado
  recursos: string[];
  destaque: boolean;
}

export interface AssinaturaAtual {
  status: StatusPlano;
  limiteAnimaisAtual: number | null; // null = ilimitado
  contagemAnimais: number;
  plano: Plano | null;
  proximaCobranca: string | null;
  canceladaEm: string | null;
}

export const planosApi = {
  listar: () => api.get("/planos") as Promise<Plano[]>,

  obterAssinatura: (fazendaId: string) =>
    api.get(`/fazendas/${fazendaId}/assinatura`) as Promise<AssinaturaAtual>,

  iniciarCheckout: (fazendaId: string, planoId: string) =>
    api.post(`/fazendas/${fazendaId}/assinatura/checkout`, { planoId }) as Promise<{
      checkoutUrl: string;
    }>,

  cancelar: (fazendaId: string) => api.post(`/fazendas/${fazendaId}/assinatura/cancelar`),
};

export function valorReais(plano: Plano): number {
  return plano.valorCentavos / 100;
}

/// Equivalente mensal do plano anual (pague 10, use 12) -- é isso que
/// aparece em destaque no card, não o total cobrado de uma vez.
export function valorMensalEquivalente(plano: Plano): number {
  return plano.periodicidade === "anual" ? valorReais(plano) / 12 : valorReais(plano);
}

export function formatarReais(valor: number): string {
  return valor.toLocaleString("pt-BR", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}
