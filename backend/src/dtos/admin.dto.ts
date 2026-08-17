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

/// Ativação manual de um plano pago (ex: pagamento combinado fora do
/// Mercado Pago) -- distinto do atualizarAssinaturaSchema acima, que mexe
/// no bloqueio geral de conta (Usuario.statusAssinatura), não no plano/
/// limite de animais (tabela assinaturas).
export const ativarPlanoManualSchema = z.object({
  planoId: z.string().uuid("planoId invalido"),
  proximaCobranca: z.coerce.date(),
});
export type AtivarPlanoManualInput = z.infer<typeof ativarPlanoManualSchema>;
