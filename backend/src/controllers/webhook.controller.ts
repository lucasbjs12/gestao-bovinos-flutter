import { Request, Response } from "express";
import { logger } from "../config/logger";
import { assinaturaService } from "../services/assinatura.service";
import { verificarAssinaturaWebhook } from "../utils/assinaturaMercadoPago";

export const webhookController = {
  /// Endpoint público (Mercado Pago não manda token de autenticação nosso,
  /// só a assinatura HMAC própria dele) -- por isso a verificação de
  /// assinatura aqui faz o papel que `autenticar` faz nas outras rotas.
  async mercadoPago(req: Request, res: Response) {
    const dataId = (req.body?.data?.id ?? req.query["data.id"]) as string | undefined;
    const tipo = (req.body?.type ?? req.query.type) as string | undefined;

    if (!dataId || !tipo) {
      res.status(200).json({ ignorado: true });
      return;
    }

    const assinado = verificarAssinaturaWebhook({
      xSignature: req.header("x-signature"),
      xRequestId: req.header("x-request-id"),
      dataId,
    });
    if (!assinado) {
      logger.warn({ dataId, tipo }, "Webhook do Mercado Pago com assinatura invalida -- ignorado");
      // 200 mesmo assim: devolver 401 só ensinaria um atacante a tentar de
      // novo com outro payload. A notificação simplesmente não é confiada.
      res.status(200).json({ ignorado: true });
      return;
    }

    // Responde rápido (Mercado Pago exige < 22s) e só então processa --
    // erro no processamento não deve virar retry infinito por timeout.
    res.status(200).json({ recebido: true });

    if (tipo === "subscription_preapproval") {
      try {
        await assinaturaService.processarWebhookPreapproval(dataId);
      } catch (err) {
        logger.error({ err, dataId }, "Falha ao processar webhook de preapproval");
      }
    }
  },
};
