import { criarApp } from "./app";
import { env } from "./config/env";
import { logger } from "./config/logger";
import { iniciarKeepAlive } from "./utils/keepAlive";

const app = criarApp();

app.listen(env.port, () => {
  logger.info(`API rodando em http://localhost:${env.port}/api/v1/health`);
  iniciarKeepAlive();
});
