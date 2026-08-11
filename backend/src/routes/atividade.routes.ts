import { Router } from "express";
import { atividadeController } from "../controllers/atividade.controller";
import { autenticar } from "../middlewares/autenticar";
import { carregarFazendaAtiva } from "../middlewares/carregarFazendaAtiva";
import { exigirAssinaturaAtiva } from "../middlewares/exigirAssinaturaAtiva";
import { validarQuery } from "../middlewares/validar";
import { paginacaoQuerySchema } from "../dtos/paginacao.dto";
import { asyncHandler } from "../utils/asyncHandler";

export const atividadeRouter = Router({ mergeParams: true });

atividadeRouter.use(autenticar, carregarFazendaAtiva, exigirAssinaturaAtiva);

// Diario de atividades e imutavel: so leitura pela API. Os registros sao
// criados internamente pelos services de cada recurso (ver atividadeRepository.registrar).
atividadeRouter.get("/", validarQuery(paginacaoQuerySchema), asyncHandler(atividadeController.listar));
