import { z } from "zod";

export const atualizarFazendaSchema = z.object({
  nome: z.string().trim().min(2, "Nome deve ter ao menos 2 caracteres"),
});
export type AtualizarFazendaInput = z.infer<typeof atualizarFazendaSchema>;
