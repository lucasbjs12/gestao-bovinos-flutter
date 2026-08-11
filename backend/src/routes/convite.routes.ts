import { Router } from "express";
import { conviteController } from "../controllers/convite.controller";
import { autenticar } from "../middlewares/autenticar";
import { carregarFazendaAtiva } from "../middlewares/carregarFazendaAtiva";
import { exigirAssinaturaAtiva } from "../middlewares/exigirAssinaturaAtiva";
import { exigirPapel } from "../middlewares/exigirPapel";
import { asyncHandler } from "../utils/asyncHandler";

// Rotas aninhadas em /fazendas/:fazendaId/convites -- so o dono gera/gerencia convites.
export const conviteRouter = Router({ mergeParams: true });

conviteRouter.use(autenticar, carregarFazendaAtiva, exigirAssinaturaAtiva, exigirPapel("dono"));

conviteRouter.get("/", asyncHandler(conviteController.listar));
conviteRouter.post("/", asyncHandler(conviteController.gerar));
