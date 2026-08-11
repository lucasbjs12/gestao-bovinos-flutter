import { Router } from "express";
import { eventoSanitarioController } from "../controllers/eventoSanitario.controller";
import { autenticar } from "../middlewares/autenticar";
import { carregarFazendaAtiva } from "../middlewares/carregarFazendaAtiva";
import { exigirAssinaturaAtiva } from "../middlewares/exigirAssinaturaAtiva";
import { exigirPapel } from "../middlewares/exigirPapel";
import { validarBody, validarQuery } from "../middlewares/validar";
import {
  atualizarEventoSanitarioSchema,
  criarEventoSanitarioSchema,
  listarEventosSanitariosQuerySchema,
} from "../dtos/eventoSanitario.dto";
import { asyncHandler } from "../utils/asyncHandler";

export const eventoSanitarioRouter = Router({ mergeParams: true });

eventoSanitarioRouter.use(autenticar, carregarFazendaAtiva, exigirAssinaturaAtiva);

eventoSanitarioRouter.get(
  "/",
  validarQuery(listarEventosSanitariosQuerySchema),
  asyncHandler(eventoSanitarioController.listar),
);
eventoSanitarioRouter.get("/:id", asyncHandler(eventoSanitarioController.buscarPorId));
eventoSanitarioRouter.post(
  "/",
  exigirPapel("dono", "convidado"),
  validarBody(criarEventoSanitarioSchema),
  asyncHandler(eventoSanitarioController.criar),
);
eventoSanitarioRouter.put(
  "/:id",
  exigirPapel("dono", "convidado"),
  validarBody(atualizarEventoSanitarioSchema),
  asyncHandler(eventoSanitarioController.atualizar),
);
eventoSanitarioRouter.delete(
  "/:id",
  exigirPapel("dono"),
  asyncHandler(eventoSanitarioController.remover),
);
