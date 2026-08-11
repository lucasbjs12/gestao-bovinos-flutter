import { Request, Response } from "express";
import { erro } from "../utils/respostaPadrao";

/// express-rate-limit por padrao responde 429 com texto puro ("Too many
/// requests..."), nao com o envelope JSON padrao da API -- os clientes
/// (site e app) tentam decodificar como JSON, falham, e mostram um erro
/// generico de "resposta invalida" que esconde a causa real (rate limit).
/// Usado como `handler` em toda instancia de rateLimit() do projeto.
export function rateLimitHandler(_req: Request, res: Response) {
  erro(res, 429, "Muitas requisicoes em pouco tempo. Aguarde alguns minutos e tente de novo.", {
    code: "rate_limited",
  });
}
