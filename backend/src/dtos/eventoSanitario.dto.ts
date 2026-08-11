import { z } from "zod";
import { TipoEventoSanitario } from "@prisma/client";
import { paginacaoQuerySchema } from "./paginacao.dto";

const camposEventoSanitario = z.object({
  tipo: z.nativeEnum(TipoEventoSanitario),
  // .nullable() nos opcionais: os clientes mandam `null` explicito em campo
  // vazio (nao omitem a chave) -- sem isso o Zod rejeita com 422.
  dataEvento: z.coerce.date().optional().nullable(),
  invernadaId: z.string().uuid().optional().nullable(),
  produtoUtilizado: z.string().trim().optional().nullable(),
  dosagem: z.string().trim().optional().nullable(),
  responsavel: z.string().trim().optional().nullable(),
  observacoes: z.string().trim().optional().nullable(),
  bovinoIds: z.array(z.string().uuid()).min(1, "Selecione ao menos um animal"),
});

export const criarEventoSanitarioSchema = camposEventoSanitario.extend({
  id: z.string().uuid().optional(),
});
export type CriarEventoSanitarioInput = z.infer<typeof criarEventoSanitarioSchema>;

export const atualizarEventoSanitarioSchema = camposEventoSanitario.partial();
export type AtualizarEventoSanitarioInput = z.infer<typeof atualizarEventoSanitarioSchema>;

export const listarEventosSanitariosQuerySchema = paginacaoQuerySchema.extend({
  tipo: z.nativeEnum(TipoEventoSanitario).optional(),
  invernadaId: z.string().uuid().optional(),
});
export type ListarEventosSanitariosQuery = z.infer<typeof listarEventosSanitariosQuerySchema>;
