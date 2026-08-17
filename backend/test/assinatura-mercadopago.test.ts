import { createHmac } from "crypto";
import request from "supertest";
import { afterEach, describe, expect, it, vi } from "vitest";
import { app } from "./helpers/app";
import { limparBanco } from "./helpers/banco";
import { registrarUsuario } from "./helpers/usuarios";
import { prisma } from "../src/config/prisma";

afterEach(async () => {
  vi.unstubAllGlobals();
  await limparBanco();
});

function assinarWebhook(dataId: string, requestId: string) {
  const ts = Math.floor(Date.now() / 1000);
  const manifesto = `id:${dataId.toLowerCase()};request-id:${requestId};ts:${ts};`;
  const v1 = createHmac("sha256", process.env.MERCADOPAGO_WEBHOOK_SECRET!)
    .update(manifesto)
    .digest("hex");
  return { xSignature: `ts=${ts},v1=${v1}`, xRequestId: requestId };
}

function mockFetchMercadoPago(respostas: {
  criarPreapproval?: object;
  buscarPreapproval?: object;
  cancelarPreapproval?: object;
}) {
  vi.stubGlobal(
    "fetch",
    vi.fn(async (url: string, opcoes: RequestInit) => {
      const metodo = opcoes.method ?? "GET";
      const corpo =
        metodo === "POST" && url.endsWith("/preapproval")
          ? respostas.criarPreapproval
          : metodo === "GET"
            ? respostas.buscarPreapproval
            : respostas.cancelarPreapproval;
      return {
        ok: true,
        status: 200,
        json: async () => corpo,
      } as Response;
    }),
  );
}

/// O controller do webhook responde 200 e só então processa (de propósito
/// -- Mercado Pago exige resposta em <22s, e o processamento não pode
/// travar isso). Em teste, isso significa que o `await` no POST do webhook
/// não garante que o UPDATE no banco já aconteceu -- espera ativamente até
/// o status esperado aparecer (ou desiste depois de um tempo).
async function aguardarStatus(
  headers: Record<string, string>,
  fazendaId: string,
  statusEsperado: string,
) {
  for (let i = 0; i < 20; i++) {
    const resposta = await request(app)
      .get(`/api/v1/fazendas/${fazendaId}/assinatura`)
      .set(headers);
    if (resposta.body.data.status === statusEsperado) return resposta;
    await new Promise((r) => setTimeout(r, 50));
  }
  throw new Error(`Status "${statusEsperado}" não apareceu a tempo`);
}

async function buscarPlanoProdutorMensal() {
  const plano = await prisma.plano.findFirstOrThrow({
    where: { slug: "produtor", periodicidade: "mensal" },
  });
  return plano;
}

describe("Checkout de assinatura", () => {
  it("cria a preapproval no Mercado Pago e devolve o link de checkout", async () => {
    const { headers, fazendaId } = await registrarUsuario();
    const plano = await buscarPlanoProdutorMensal();

    mockFetchMercadoPago({
      criarPreapproval: {
        id: "preapproval-123",
        status: "pending",
        init_point: "https://mercadopago.example/checkout/preapproval-123",
      },
    });

    const resposta = await request(app)
      .post(`/api/v1/fazendas/${fazendaId}/assinatura/checkout`)
      .set(headers)
      .send({ planoId: plano.id })
      .expect(200);

    expect(resposta.body.data.checkoutUrl).toBe(
      "https://mercadopago.example/checkout/preapproval-123",
    );

    const assinatura = await request(app)
      .get(`/api/v1/fazendas/${fazendaId}/assinatura`)
      .set(headers);
    expect(assinatura.body.data.status).toBe("pendente");
  });
});

describe("Webhook do Mercado Pago", () => {
  async function prepararCheckout() {
    const usuario = await registrarUsuario();
    const plano = await buscarPlanoProdutorMensal();
    mockFetchMercadoPago({
      criarPreapproval: { id: "preapproval-abc", status: "pending", init_point: "https://x" },
    });
    await request(app)
      .post(`/api/v1/fazendas/${usuario.fazendaId}/assinatura/checkout`)
      .set(usuario.headers)
      .send({ planoId: plano.id })
      .expect(200);
    return { ...usuario, plano };
  }

  it("ignora notificação com assinatura inválida -- não ativa nada", async () => {
    const { headers, fazendaId } = await prepararCheckout();

    await request(app)
      .post("/api/v1/webhooks/mercadopago")
      .set("x-signature", "ts=1,v1=assinatura-forjada")
      .set("x-request-id", "req-1")
      .send({ type: "subscription_preapproval", data: { id: "preapproval-abc" } })
      .expect(200);

    const assinatura = await request(app)
      .get(`/api/v1/fazendas/${fazendaId}/assinatura`)
      .set(headers);
    expect(assinatura.body.data.status).toBe("pendente");
  });

  it("com assinatura válida e status 'authorized', ativa o plano com o limite certo", async () => {
    const { headers, fazendaId, plano } = await prepararCheckout();

    mockFetchMercadoPago({
      buscarPreapproval: { id: "preapproval-abc", status: "authorized" },
    });
    const { xSignature, xRequestId } = assinarWebhook("preapproval-abc", "req-2");

    await request(app)
      .post("/api/v1/webhooks/mercadopago")
      .set("x-signature", xSignature)
      .set("x-request-id", xRequestId)
      .send({ type: "subscription_preapproval", data: { id: "preapproval-abc" } })
      .expect(200);

    const assinatura = await aguardarStatus(headers, fazendaId, "ativo");
    expect(assinatura.body.data.limiteAnimaisAtual).toBe(plano.limiteAnimais);
  });
});

describe("Cancelamento de assinatura", () => {
  it("só deixa cancelar quando há assinatura paga ativa", async () => {
    const { headers, fazendaId } = await registrarUsuario();

    await request(app)
      .post(`/api/v1/fazendas/${fazendaId}/assinatura/cancelar`)
      .set(headers)
      .expect(422);
  });

  it("cancela no Mercado Pago e marca como cancelado, sem apagar nada", async () => {
    const usuario = await registrarUsuario();
    const plano = await buscarPlanoProdutorMensal();

    mockFetchMercadoPago({
      criarPreapproval: { id: "preapproval-xyz", status: "pending", init_point: "https://x" },
    });
    await request(app)
      .post(`/api/v1/fazendas/${usuario.fazendaId}/assinatura/checkout`)
      .set(usuario.headers)
      .send({ planoId: plano.id })
      .expect(200);

    mockFetchMercadoPago({
      buscarPreapproval: { id: "preapproval-xyz", status: "authorized" },
    });
    const { xSignature, xRequestId } = assinarWebhook("preapproval-xyz", "req-3");
    await request(app)
      .post("/api/v1/webhooks/mercadopago")
      .set("x-signature", xSignature)
      .set("x-request-id", xRequestId)
      .send({ type: "subscription_preapproval", data: { id: "preapproval-xyz" } })
      .expect(200);
    await aguardarStatus(usuario.headers, usuario.fazendaId, "ativo");

    mockFetchMercadoPago({
      cancelarPreapproval: { id: "preapproval-xyz", status: "cancelled" },
    });
    await request(app)
      .post(`/api/v1/fazendas/${usuario.fazendaId}/assinatura/cancelar`)
      .set(usuario.headers)
      .expect(200);

    const assinatura = await request(app)
      .get(`/api/v1/fazendas/${usuario.fazendaId}/assinatura`)
      .set(usuario.headers);
    expect(assinatura.body.data.status).toBe("cancelado");
    // Continua com o limite do plano pago -- só volta pro Gratuito quando o
    // período já pago (proximaCobranca) passar, não na hora do cancelamento.
    expect(assinatura.body.data.limiteAnimaisAtual).toBe(plano.limiteAnimais);
  });
});
