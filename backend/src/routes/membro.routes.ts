import { Router } from "express";
import { membroController } from "../controllers/membro.controller";
import { autenticar } from "../middlewares/autenticar";
import { carregarFazendaAtiva } from "../middlewares/carregarFazendaAtiva";
import { exigirAssinaturaAtiva } from "../middlewares/exigirAssinaturaAtiva";
import { exigirPapel } from "../middlewares/exigirPapel";
import { asyncHandler } from "../utils/asyncHandler";

export const membroRouter = Router({ mergeParams: true });

membroRouter.use(autenticar, carregarFazendaAtiva, exigirAssinaturaAtiva);

membroRouter.get("/", asyncHandler(membroController.listar));
membroRouter.delete("/:usuarioId", exigirPapel("dono"), asyncHandler(membroController.remover));
