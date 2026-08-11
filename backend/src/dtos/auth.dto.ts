import { z } from "zod";

export const registroSchema = z.object({
  nome: z.string().trim().min(2, "Nome deve ter ao menos 2 caracteres"),
  email: z.string().trim().toLowerCase().email("E-mail invalido"),
  senha: z.string().min(8, "Senha deve ter ao menos 8 caracteres"),
  nomeFazenda: z.string().trim().min(2).optional(),
});
export type RegistroInput = z.infer<typeof registroSchema>;

export const loginSchema = z.object({
  email: z.string().trim().toLowerCase().email("E-mail invalido"),
  senha: z.string().min(1, "Senha e obrigatoria"),
});
export type LoginInput = z.infer<typeof loginSchema>;

export const refreshSchema = z.object({
  refreshToken: z.string().min(1, "refreshToken e obrigatorio"),
});
export type RefreshInput = z.infer<typeof refreshSchema>;

export const esqueciSenhaSchema = z.object({
  email: z.string().trim().toLowerCase().email("E-mail invalido"),
});
export type EsqueciSenhaInput = z.infer<typeof esqueciSenhaSchema>;

export const redefinirSenhaSchema = z.object({
  token: z.string().min(1, "token e obrigatorio"),
  novaSenha: z.string().min(8, "Senha deve ter ao menos 8 caracteres"),
});
export type RedefinirSenhaInput = z.infer<typeof redefinirSenhaSchema>;

export const alterarSenhaSchema = z.object({
  senhaAtual: z.string().min(1, "senhaAtual e obrigatoria"),
  novaSenha: z.string().min(8, "Senha deve ter ao menos 8 caracteres"),
});
export type AlterarSenhaInput = z.infer<typeof alterarSenhaSchema>;

export const excluirContaSchema = z.object({
  senha: z.string().min(1, "senha e obrigatoria"),
});
export type ExcluirContaInput = z.infer<typeof excluirContaSchema>;
