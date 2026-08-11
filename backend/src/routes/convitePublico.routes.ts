import { Router } from "express";
import { conviteController } from "../controllers/convite.controller";
import { autenticar } from "../middlewares/autenticar";
import { asyncHandler } from "../utils/asyncHandler";

// Rotas top-level /convites/:codigo -- o usuario ainda NAO e membro da fazenda
// nesse ponto, entao nao passam por carregarFazendaAtiva (so autenticar).
export const convitePublicoRouter = Router();

convitePublicoRouter.get("/:codigo", autenticar, asyncHandler(conviteController.validar));
convitePublicoRouter.post("/:codigo/aceitar", autenticar, asyncHandler(conviteController.aceitar));
