import { Request, Response } from "express";
import { planoRepository } from "../repositories/plano.repository";
import { sucesso } from "../utils/respostaPadrao";

export const planoController = {
  async listar(_req: Request, res: Response) {
    const planos = await planoRepository.listarAtivos();
    sucesso(res, planos);
  },
};
