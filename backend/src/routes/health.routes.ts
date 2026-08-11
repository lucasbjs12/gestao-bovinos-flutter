import { Router } from "express";
import { sucesso } from "../utils/respostaPadrao";

export const healthRouter = Router();

healthRouter.get("/", (_req, res) => {
  sucesso(res, { status: "ok", timestamp: new Date().toISOString() }, "API no ar");
});
