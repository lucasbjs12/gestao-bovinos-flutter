import { Resend } from "resend";
import { env } from "../config/env";
import { AppError } from "../exceptions/AppError";
import { logger } from "../config/logger";

let cliente: Resend | null = null;

function obterCliente(): Resend {
  if (!env.resend.apiKey) {
    throw new AppError(
      503,
      "email_nao_configurado",
      "Envio de e-mail nao configurado neste ambiente (variavel RESEND_API_KEY ausente)",
    );
  }
  if (!cliente) {
    cliente = new Resend(env.resend.apiKey);
  }
  return cliente;
}

export const emailService = {
  async enviarResetSenha(destinatario: string, nome: string, linkReset: string) {
    const resend = obterCliente();
    const { error } = await resend.emails.send({
      from: `Gestao de Rebanho <${env.resend.fromEmail}>`,
      to: destinatario,
      subject: "Redefinir sua senha",
      html: `
        <p>Ola, ${nome}.</p>
        <p>Recebemos um pedido para redefinir a senha da sua conta no Gestao de Rebanho.</p>
        <p><a href="${linkReset}">Clique aqui para escolher uma nova senha</a></p>
        <p>Este link expira em 1 hora. Se voce nao pediu essa redefinicao, ignore este e-mail.</p>
      `,
    });
    if (error) {
      logger.error({ error }, "Falha ao enviar e-mail de reset de senha");
      throw new AppError(502, "email_falhou", "Nao foi possivel enviar o e-mail de redefinicao");
    }
  },
};
