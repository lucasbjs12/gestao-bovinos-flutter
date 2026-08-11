import { logger } from "../config/logger";

const INTERVALO_MS = 10 * 60 * 1000; // 10 minutos -- menor que os 15min de inatividade que fazem o Render dormir o servico free

/**
 * Faz self-ping periodico no proprio health check pra evitar que o Render
 * (plano free) coloque o servico pra dormir por inatividade. So roda
 * quando `RENDER_EXTERNAL_URL` existe (variavel que o proprio Render
 * injeta automaticamente com a URL publica do servico) -- em dev local ou
 * em outro provedor essa var nao existe, entao isso fica desligado sozinho.
 *
 * Efeito colateral: mantem o servico sempre ligado 24/7, o que consome as
 * horas gratuitas do mes mais rapido do que o uso esporadico que o free
 * tier foi pensado pra suportar. Trade-off aceito de proposito (evitar o
 * "acordar" lento na primeira requisicao depois de dormir).
 */
export function iniciarKeepAlive() {
  const url = process.env.RENDER_EXTERNAL_URL;
  if (!url) return;

  const pingar = () => {
    fetch(`${url}/api/v1/health`).catch((err) => {
      logger.warn({ err }, "Falha no self-ping de keep-alive");
    });
  };

  setInterval(pingar, INTERVALO_MS);
  logger.info(`Keep-alive ativado: self-ping a cada ${INTERVALO_MS / 60000}min em ${url}`);
}
