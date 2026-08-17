import { Router } from "express";
import { assinaturaController } from "../controllers/assinatura.controller";
import { autenticar } from "../middlewares/autenticar";
import { carregarFazendaAtiva } from "../middlewares/carregarFazendaAtiva";
import { exigirPapel } from "../middlewares/exigirPapel";
import { validarBody } from "../middlewares/validar";
import { iniciarCheckoutSchema } from "../dtos/assinatura.dto";
import { asyncHandler } from "../utils/asyncHandler";

export const assinaturaRouter = Router({ mergeParams: true });

// Sem exigirAssinaturaAtiva de propósito: essa rota tem que continuar
// respondendo mesmo se a assinatura estiver vencida/gratuita -- é como a
// tela de Planos descobre isso pra mostrar o card de upgrade certo.
assinaturaRouter.use(autenticar, carregarFazendaAtiva);

// Qualquer papel pode ver (convidado também precisa saber quanto do limite
// já foi usado).
assinaturaRouter.get("/", asyncHandler(assinaturaController.obter));

// Mudar o plano é coisa de dono -- a assinatura é dele, um convidado não
// pode contratar/cancelar em nome de quem o convidou.
assinaturaRouter.post(
  "/checkout",
  exigirPapel("dono"),
  validarBody(iniciarCheckoutSchema),
  asyncHandler(assinaturaController.checkout),
);
assinaturaRouter.post("/cancelar", exigirPapel("dono"), asyncHandler(assinaturaController.cancelar));
