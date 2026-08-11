import { z } from "zod";
import { CategoriaBovino, MotivoBaixa } from "@prisma/client";
import { paginacaoQuerySchema } from "./paginacao.dto";

const camposBovino = z.object({
  // .nullable() em todos os opcionais: o app Flutter (e o site) mandam
  // `null` explicito em campo vazio (nao omitem a chave), diferente do
  // Firestore -- sem isso o Zod rejeita com 422 ("Expected string/number,
  // received null") assim que o valor for esvaziado.
  nomeAnimal: z.string().trim().optional().nullable(),
  codigoEpc: z.string().trim().optional().nullable(),
  codigoInterno: z.string().trim().optional().nullable(),
  numeroBrinco: z.string().trim().min(1, "Numero do brinco e obrigatorio"),
  raca: z.string().trim().optional().nullable(),
  dataNascimento: z.coerce.date().optional().nullable(),
  pesoAtualKg: z.coerce.number().positive().optional().nullable(),
  pelagem: z.string().trim().optional().nullable(),
  categoria: z.nativeEnum(CategoriaBovino),
  origem: z.string().trim().optional().nullable(),
  observacoes: z.string().trim().optional().nullable(),
  foto: z.string().trim().url().optional().nullable(),
  invernadaId: z.string().uuid().optional().nullable(),
  idMae: z.string().uuid().optional().nullable(),
  estaDeCria: z.boolean().default(false),
});

export const criarBovinoSchema = camposBovino.extend({
  // Gerado no cliente (offline-first: precisa do id antes de qualquer rede)
  // e aceito aqui como o id de verdade -- se omitido, o Postgres gera um.
  id: z.string().uuid().optional(),
});
export type CriarBovinoInput = z.infer<typeof criarBovinoSchema>;

export const atualizarBovinoSchema = camposBovino.partial();
export type AtualizarBovinoInput = z.infer<typeof atualizarBovinoSchema>;

export const registrarBaixaSchema = z.object({
  motivo: z.nativeEnum(MotivoBaixa),
  observacoes: z.string().trim().optional().nullable(),
  dataBaixa: z.coerce.date(),
});
export type RegistrarBaixaInput = z.infer<typeof registrarBaixaSchema>;

export const listarBovinosQuerySchema = paginacaoQuerySchema.extend({
  invernadaId: z.string().uuid().optional(),
  categoria: z.nativeEnum(CategoriaBovino).optional(),
  ordenarPor: z.enum(["brinco", "nome", "categoria", "peso"]).default("brinco"),
});
export type ListarBovinosQuery = z.infer<typeof listarBovinosQuerySchema>;
