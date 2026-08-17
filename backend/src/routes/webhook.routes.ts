import { Router } from "express";
import { webhookController } from "../controllers/webhook.controller";
import { asyncHandler } from "../utils/asyncHandler";

export const webhookRouter = Router();

// Público de propósito -- Mercado Pago não manda Bearer token, a
// verificação é a assinatura HMAC dentro do controller.
webhookRouter.post("/mercadopago", asyncHandler(webhookController.mercadoPago));
