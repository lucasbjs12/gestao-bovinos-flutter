import { Router } from "express";
import { uploadController } from "../controllers/upload.controller";
import { autenticar } from "../middlewares/autenticar";
import { carregarFazendaAtiva } from "../middlewares/carregarFazendaAtiva";
import { exigirAssinaturaAtiva } from "../middlewares/exigirAssinaturaAtiva";
import { exigirPapel } from "../middlewares/exigirPapel";
import { validarQuery } from "../middlewares/validar";
import { assinarUploadQuerySchema } from "../dtos/upload.dto";
import { asyncHandler } from "../utils/asyncHandler";

export const uploadRouter = Router({ mergeParams: true });

uploadRouter.use(autenticar, carregarFazendaAtiva, exigirAssinaturaAtiva);

// GET, nao POST: e uma operacao so-leitura (devolve uma assinatura, nao cria
// nada) -- e o app Flutter (ja publicado) chama com GET, entao o servidor
// precisa bater com o client em vez do contrario.
uploadRouter.get(
  "/assinar",
  exigirPapel("dono", "convidado"),
  validarQuery(assinarUploadQuerySchema),
  asyncHandler(uploadController.assinar),
);
