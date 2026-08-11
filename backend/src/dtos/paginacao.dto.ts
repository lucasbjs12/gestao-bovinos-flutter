import { z } from "zod";

export const paginacaoQuerySchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(30),
  busca: z.string().trim().min(1).optional(),
});
export type PaginacaoQuery = z.infer<typeof paginacaoQuerySchema>;
