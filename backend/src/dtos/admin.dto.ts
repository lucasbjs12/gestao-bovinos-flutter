import { z } from "zod";
import { StatusAssinatura } from "@prisma/client";
import { paginacaoQuerySchema } from "./paginacao.dto";

export const listarUsuariosQuerySchema = paginacaoQuerySchema;
export type ListarUsuariosQuery = z.infer<typeof listarUsuariosQuerySchema>;

export const atualizarAssinaturaSchema = z.object({
  statusAssinatura: z.nativeEnum(StatusAssinatura),
  plano: z.string().trim().optional(),
  vencimento: z.coerce.date().optional(),
});
export type AtualizarAssinaturaInput = z.infer<typeof atualizarAssinaturaSchema>;
