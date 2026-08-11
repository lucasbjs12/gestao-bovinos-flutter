import { Request, Response } from "express";
import { uploadService } from "../services/upload.service";
import { sucesso } from "../utils/respostaPadrao";
import type { AssinarUploadQuery } from "../dtos/upload.dto";

export const uploadController = {
  async assinar(req: Request, res: Response) {
    const { pasta } = req.query as unknown as AssinarUploadQuery;
    const payload = uploadService.assinarUpload(req.fazendaAtiva!.id, pasta);
    sucesso(res, payload);
  },
};
