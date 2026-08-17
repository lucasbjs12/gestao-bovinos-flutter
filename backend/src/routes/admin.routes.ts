import { Router } from "express";
import { adminController } from "../controllers/admin.controller";
import { autenticar } from "../middlewares/autenticar";
import { exigirAdmin } from "../middlewares/exigirAdmin";
import { validarBody, validarQuery } from "../middlewares/validar";
import {
  ativarPlanoManualSchema,
  atualizarAssinaturaSchema,
  listarUsuariosQuerySchema,
} from "../dtos/admin.dto";
import { asyncHandler } from "../utils/asyncHandler";

export const adminRouter = Router();

adminRouter.use(autenticar, exigirAdmin);

adminRouter.get(
  "/usuarios",
  validarQuery(listarUsuariosQuerySchema),
  asyncHandler(adminController.listarUsuarios),
);
adminRouter.patch(
  "/usuarios/:id/assinatura",
  validarBody(atualizarAssinaturaSchema),
  asyncHandler(adminController.atualizarAssinatura),
);
adminRouter.post(
  "/usuarios/:id/assinatura/ativar-plano",
  validarBody(ativarPlanoManualSchema),
  asyncHandler(adminController.ativarPlano),
);
