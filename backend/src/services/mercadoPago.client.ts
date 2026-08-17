import { env } from "../config/env";
import { AppError } from "../exceptions/AppError";

const BASE_URL = "https://api.mercadopago.com";

interface PreapprovalResposta {
  id: string;
  status: "pending" | "authorized" | "paused" | "cancelled";
  init_point?: string;
  external_reference?: string;
  date_created?: string;
}

function exigirAccessToken(): string {
  if (!env.mercadoPago.accessToken) {
    throw new AppError(
      503,
      "pagamento_nao_configurado",
      "Cobranca nao configurada neste ambiente (variavel MERCADOPAGO_ACCESS_TOKEN ausente)",
    );
  }
  return env.mercadoPago.accessToken;
}

async function chamar<T>(caminho: string, opcoes: RequestInit): Promise<T> {
  const resposta = await fetch(`${BASE_URL}${caminho}`, {
    ...opcoes,
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${exigirAccessToken()}`,
      ...opcoes.headers,
    },
  });
  const corpo = (await resposta.json().catch(() => null)) as { message?: string } | null;
  if (!resposta.ok) {
    throw new AppError(
      502,
      "mercadopago_falhou",
      `Mercado Pago recusou a operacao (${resposta.status}): ${corpo?.message ?? "erro desconhecido"}`,
      corpo,
    );
  }
  return corpo as T;
}

export const mercadoPagoClient = {
  /// Cria uma assinatura recorrente "com pagamento pendente": devolve um
  /// link (init_point) pro produtor terminar o cadastro do meio de
  /// pagamento no proprio Mercado Pago -- nada de cartao passa pelo nosso
  /// backend.
  criarPreapproval(dados: {
    reason: string;
    externalReference: string;
    payerEmail: string;
    valorReais: number;
    frequencia: { frequency: number; frequencyType: "months" | "days" };
    backUrl: string;
  }) {
    return chamar<PreapprovalResposta>("/preapproval", {
      method: "POST",
      body: JSON.stringify({
        reason: dados.reason,
        external_reference: dados.externalReference,
        payer_email: dados.payerEmail,
        back_url: dados.backUrl,
        status: "pending",
        auto_recurring: {
          frequency: dados.frequencia.frequency,
          frequency_type: dados.frequencia.frequencyType,
          transaction_amount: dados.valorReais,
          currency_id: "BRL",
        },
      }),
    });
  },

  /// Sempre usado depois de um webhook -- nunca confiar no corpo da
  /// notificacao sozinho, ele so avisa "algo mudou"; isso aqui busca o
  /// estado de verdade direto na API.
  buscarPreapproval(id: string) {
    return chamar<PreapprovalResposta>(`/preapproval/${id}`, { method: "GET" });
  },

  cancelarPreapproval(id: string) {
    return chamar<PreapprovalResposta>(`/preapproval/${id}`, {
      method: "PUT",
      body: JSON.stringify({ status: "cancelled" }),
    });
  },
};
