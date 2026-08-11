import { z } from "zod";

export const criarMovimentacaoSchema = z.object({
  bovinoId: z.string().uuid(),
  novaInvernadaId: z.string().uuid(),
  data: z.coerce.date(),
  responsavel: z.string().trim().optional().nullable(),
  observacoes: z.string().trim().optional().nullable(),
});
export type CriarMovimentacaoInput = z.infer<typeof criarMovimentacaoSchema>;
