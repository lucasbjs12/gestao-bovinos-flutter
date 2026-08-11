import { Router } from "express";
import { invernadaController } from "../controllers/invernada.controller";
import { autenticar } from "../middlewares/autenticar";
import { carregarFazendaAtiva } from "../middlewares/carregarFazendaAtiva";
import { exigirAssinaturaAtiva } from "../middlewares/exigirAssinaturaAtiva";
import { exigirPapel } from "../middlewares/exigirPapel";
import { validarBody, validarQuery } from "../middlewares/validar";
import { atualizarInvernadaSchema, criarInvernadaSchema } from "../dtos/invernada.dto";
import { paginacaoQuerySchema } from "../dtos/paginacao.dto";
import { asyncHandler } from "../utils/asyncHandler";

export const invernadaRouter = Router({ mergeParams: true });

invernadaRouter.use(autenticar, carregarFazendaAtiva, exigirAssinaturaAtiva);

invernadaRouter.get("/", validarQuery(paginacaoQuerySchema), asyncHandler(invernadaController.listar));
invernadaRouter.get("/:id", asyncHandler(invernadaController.buscarPorId));
invernadaRouter.get(
  "/:id/movimentacoes",
  validarQuery(paginacaoQuerySchema),
  asyncHandler(invernadaController.listarMovimentacoes),
);
invernadaRouter.post(
  "/",
  exigirPapel("dono", "convidado"),
  validarBody(criarInvernadaSchema),
  asyncHandler(invernadaController.criar),
);
invernadaRouter.put(
  "/:id",
  exigirPapel("dono", "convidado"),
  validarBody(atualizarInvernadaSchema),
  asyncHandler(invernadaController.atualizar),
);
invernadaRouter.delete("/:id", exigirPapel("dono"), asyncHandler(invernadaController.remover));
