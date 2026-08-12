import { Router } from "express";
import rateLimit from "express-rate-limit";
import { authController } from "../controllers/auth.controller";
import { autenticar } from "../middlewares/autenticar";
import { validarBody } from "../middlewares/validar";
import {
  alterarSenhaSchema,
  esqueciSenhaSchema,
  excluirContaSchema,
  loginSchema,
  redefinirSenhaSchema,
  refreshSchema,
  registroSchema,
  verificarEmailSchema,
} from "../dtos/auth.dto";
import { asyncHandler } from "../utils/asyncHandler";
import { env } from "../config/env";
import { rateLimitHandler } from "../middlewares/rateLimitHandler";

export const authRouter = Router();

// Rotas sensiveis (login/registro) tem rate limit proprio, mais restrito que o global.
const limitadorAuth = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: env.nodeEnv === "test" ? 100_000 : 20,
  standardHeaders: true,
  legacyHeaders: false,
  handler: rateLimitHandler,
});

authRouter.post("/registro", limitadorAuth, validarBody(registroSchema), asyncHandler(authController.registrar));
authRouter.post("/login", limitadorAuth, validarBody(loginSchema), asyncHandler(authController.login));
authRouter.post("/refresh", limitadorAuth, validarBody(refreshSchema), asyncHandler(authController.refresh));
authRouter.post("/logout", validarBody(refreshSchema), asyncHandler(authController.logout));
authRouter.get("/me", autenticar, asyncHandler(authController.me));
authRouter.post(
  "/esqueci-senha",
  limitadorAuth,
  validarBody(esqueciSenhaSchema),
  asyncHandler(authController.esqueciSenha),
);
authRouter.post(
  "/redefinir-senha",
  limitadorAuth,
  validarBody(redefinirSenhaSchema),
  asyncHandler(authController.redefinirSenha),
);
authRouter.patch(
  "/senha",
  autenticar,
  limitadorAuth,
  validarBody(alterarSenhaSchema),
  asyncHandler(authController.alterarSenha),
);
authRouter.delete(
  "/me",
  autenticar,
  validarBody(excluirContaSchema),
  asyncHandler(authController.excluirConta),
);
authRouter.post(
  "/verificar-email",
  limitadorAuth,
  validarBody(verificarEmailSchema),
  asyncHandler(authController.verificarEmail),
);
authRouter.post(
  "/reenviar-verificacao",
  autenticar,
  limitadorAuth,
  asyncHandler(authController.reenviarVerificacao),
);
