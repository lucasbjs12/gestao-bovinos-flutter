import { z } from "zod";

const camposInvernada = z.object({
  descricao: z.string().trim().min(1, "Descricao e obrigatoria"),
  // .nullable() nos opcionais: os clientes mandam `null` explicito em campo
  // vazio (nao omitem a chave) -- sem isso o Zod rejeita com 422.
  hectares: z.coerce.number().positive().optional().nullable(),
  urlFoto: z.string().trim().url().optional().nullable(),
  observacoes: z.string().trim().optional().nullable(),
});

export const criarInvernadaSchema = camposInvernada.extend({
  id: z.string().uuid().optional(),
});
export type CriarInvernadaInput = z.infer<typeof criarInvernadaSchema>;

export const atualizarInvernadaSchema = camposInvernada.partial();
export type AtualizarInvernadaInput = z.infer<typeof atualizarInvernadaSchema>;
