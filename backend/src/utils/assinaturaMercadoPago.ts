import { createHmac, timingSafeEqual } from "crypto";
import { env } from "../config/env";

/// Confere que a notificacao realmente veio do Mercado Pago (e nao de
/// qualquer um batendo direto em /webhooks/mercadopago tentando ativar um
/// plano de graca). Formato documentado: header `x-signature` traz
/// `ts=...,v1=...`; o manifesto assinado e' `id:{dataId};request-id:{xRequestId};ts:{ts};`
/// em HMAC-SHA256 com o webhook secret.
export function verificarAssinaturaWebhook(opts: {
  xSignature: string | undefined;
  xRequestId: string | undefined;
  dataId: string;
}): boolean {
  const { webhookSecret } = env.mercadoPago;
  if (!webhookSecret || !opts.xSignature || !opts.xRequestId) return false;

  const partes = Object.fromEntries(
    opts.xSignature.split(",").map((par) => {
      const [chave, valor] = par.split("=");
      return [chave?.trim(), valor?.trim()];
    }),
  );
  const ts = partes.ts;
  const v1 = partes.v1;
  if (!ts || !v1) return false;

  const manifesto = `id:${opts.dataId.toLowerCase()};request-id:${opts.xRequestId};ts:${ts};`;
  const esperado = createHmac("sha256", webhookSecret).update(manifesto).digest("hex");

  const bufEsperado = Buffer.from(esperado);
  const bufRecebido = Buffer.from(v1);
  if (bufEsperado.length !== bufRecebido.length) return false;
  return timingSafeEqual(bufEsperado, bufRecebido);
}
