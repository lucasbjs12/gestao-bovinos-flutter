import { Router } from "express";
import { movimentacaoController } from "../controllers/movimentacao.controller";
import { autenticar } from "../middlewares/autenticar";
import { carregarFazendaAtiva } from "../middlewares/carregarFazendaAtiva";
import { exigirAssinaturaAtiva } from "../middlewares/exigirAssinaturaAtiva";
import { exigirPapel } from "../middlewares/exigirPapel";
import { validarBody } from "../middlewares/validar";
import { criarMovimentacaoSchema } from "../dtos/movimentacao.dto";
import { asyncHandler } from "../utils/asyncHandler";

export const movimentacaoRouter = Router({ mergeParams: true });

movimentacaoRouter.use(autenticar, carregarFazendaAtiva, exigirAssinaturaAtiva);

movimentacaoRouter.post(
  "/",
  exigirPapel("dono", "convidado"),
  validarBody(criarMovimentacaoSchema),
  asyncHandler(movimentacaoController.criar),
);
