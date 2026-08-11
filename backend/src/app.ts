import express, { Express } from "express";
import cors from "cors";
import helmet from "helmet";
import rateLimit from "express-rate-limit";
import { pinoHttp } from "pino-http";
import { env } from "./config/env";
import { logger } from "./config/logger";
import { apiRouter } from "./routes";
import { errorHandler, rotaNaoEncontrada } from "./middlewares/errorHandler";
import { rateLimitHandler } from "./middlewares/rateLimitHandler";

export function criarApp(): Express {
  const app = express();

  // CSP desligada: API pura JSON consumida pelo app Flutter (CSP e uma protecao
  // de navegador) + evita bloquear os scripts inline do Swagger UI em /docs.
  app.use(helmet({ contentSecurityPolicy: false }));
  app.use(cors({ origin: env.corsOrigin }));
  app.use(express.json());
  app.use(pinoHttp({ logger }));

  // Em teste automatizado, muitas chamadas saem do mesmo IP (127.0.0.1) num
  // intervalo curto -- limite baixo derrubaria a suite com 429 sem relacao
  // com o que esta sendo testado.
  const limitador = rateLimit({
    windowMs: env.rateLimit.windowMs,
    max: env.nodeEnv === "test" ? 100_000 : env.rateLimit.max,
    standardHeaders: true,
    legacyHeaders: false,
    handler: rateLimitHandler,
  });
  app.use(limitador);

  app.use("/api", apiRouter);

  app.use(rotaNaoEncontrada);
  app.use(errorHandler);

  return app;
}
