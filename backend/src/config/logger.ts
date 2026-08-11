import pino from "pino";
import { env } from "./env";

export const logger = pino({
  level: env.nodeEnv === "test" ? "silent" : env.nodeEnv === "production" ? "info" : "debug",
  // pino-http loga os headers da requisicao por padrao, incluindo
  // Authorization -- sem isso, o access token (JWT) de todo usuario
  // autenticado fica em texto puro no log (achado numa revisao de
  // seguranca: JWTs completos apareceram no log local varias vezes).
  redact: {
    paths: [
      "req.headers.authorization",
      "req.headers.cookie",
      "res.headers['set-cookie']",
    ],
    censor: "[REDACTED]",
  },
  transport:
    env.nodeEnv === "production" || env.nodeEnv === "test"
      ? undefined
      : { target: "pino-pretty", options: { colorize: true } },
});
