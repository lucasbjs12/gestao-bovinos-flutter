import { Request, Response } from "express";
import { fazendaRepository } from "../repositories/fazenda.repository";
import { sucesso } from "../utils/respostaPadrao";
import type { AtualizarFazendaInput } from "../dtos/fazenda.dto";

export const fazendaController = {
  async atualizar(req: Request<unknown, unknown, AtualizarFazendaInput>, res: Response) {
    const fazenda = await fazendaRepository.atualizar(req.fazendaAtiva!.id, req.body);
    sucesso(res, fazenda, "Fazenda atualizada");
  },
};
