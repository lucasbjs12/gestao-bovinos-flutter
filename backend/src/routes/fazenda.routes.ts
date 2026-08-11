import { Router } from "express";
import { fazendaController } from "../controllers/fazenda.controller";
import { autenticar } from "../middlewares/autenticar";
import { carregarFazendaAtiva } from "../middlewares/carregarFazendaAtiva";
import { exigirAssinaturaAtiva } from "../middlewares/exigirAssinaturaAtiva";
import { exigirPapel } from "../middlewares/exigirPapel";
import { validarBody } from "../middlewares/validar";
import { atualizarFazendaSchema } from "../dtos/fazenda.dto";
import { asyncHandler } from "../utils/asyncHandler";

export const fazendaRouter = Router({ mergeParams: true });

fazendaRouter.use(autenticar, carregarFazendaAtiva, exigirAssinaturaAtiva);

fazendaRouter.patch(
  "/",
  exigirPapel("dono"),
  validarBody(atualizarFazendaSchema),
  asyncHandler(fazendaController.atualizar),
);
