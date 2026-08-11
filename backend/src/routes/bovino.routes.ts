import { Router } from "express";
import { bovinoController } from "../controllers/bovino.controller";
import { autenticar } from "../middlewares/autenticar";
import { carregarFazendaAtiva } from "../middlewares/carregarFazendaAtiva";
import { exigirAssinaturaAtiva } from "../middlewares/exigirAssinaturaAtiva";
import { exigirPapel } from "../middlewares/exigirPapel";
import { validarBody, validarQuery } from "../middlewares/validar";
import {
  atualizarBovinoSchema,
  criarBovinoSchema,
  listarBovinosQuerySchema,
  registrarBaixaSchema,
} from "../dtos/bovino.dto";
import { asyncHandler } from "../utils/asyncHandler";

export const bovinoRouter = Router({ mergeParams: true });

bovinoRouter.use(autenticar, carregarFazendaAtiva, exigirAssinaturaAtiva);

bovinoRouter.get("/", validarQuery(listarBovinosQuerySchema), asyncHandler(bovinoController.listar));
bovinoRouter.get("/:id", asyncHandler(bovinoController.buscarPorId));
bovinoRouter.post(
  "/",
  exigirPapel("dono", "convidado"),
  validarBody(criarBovinoSchema),
  asyncHandler(bovinoController.criar),
);
bovinoRouter.put(
  "/:id",
  exigirPapel("dono", "convidado"),
  validarBody(atualizarBovinoSchema),
  asyncHandler(bovinoController.atualizar),
);
bovinoRouter.patch(
  "/:id/baixa",
  exigirPapel("dono", "convidado"),
  validarBody(registrarBaixaSchema),
  asyncHandler(bovinoController.registrarBaixa),
);
bovinoRouter.patch(
  "/:id/reativar",
  exigirPapel("dono", "convidado"),
  asyncHandler(bovinoController.reativar),
);
bovinoRouter.delete("/:id", exigirPapel("dono"), asyncHandler(bovinoController.remover));
