import { Router } from "express";
import { planoController } from "../controllers/plano.controller";
import { autenticar } from "../middlewares/autenticar";
import { asyncHandler } from "../utils/asyncHandler";

export const planoRouter = Router();

// Lista pública dos planos (valor/limite ficam 100% no banco -- ver seed da
// migration assinaturas_e_planos) -- só exige estar logado, sem escopo de
// fazenda: é a mesma lista pra qualquer usuário.
planoRouter.get("/", autenticar, asyncHandler(planoController.listar));
