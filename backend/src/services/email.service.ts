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

function escaparHtml(texto: string): string {
  return texto
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

// Layout em tabelas + estilos inline: e-mail nao roda CSS externo/JS, entao
// isso e o que sobrevive na maioria dos clientes (Gmail, Outlook, Apple Mail).
// Os dois e-mails (reset de senha, verificacao de cadastro) compartilham essa
// mesma moldura -- so mudam titulo/corpo/texto do botao.
function envolverEmail(opts: { titulo: string; corpoHtml: string; botaoLabel: string; link: string }): string {
  return `
<!DOCTYPE html>
<html lang="pt-BR">
  <body style="margin:0; padding:0; background-color:#f0ece3; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f0ece3; padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="480" cellpadding="0" cellspacing="0" style="max-width:480px; width:100%; background-color:#ffffff; border-radius:16px; overflow:hidden; border:1px solid #e4e0d8;">
            <tr>
              <td style="background-color:#04100a; padding:28px 32px;">
                <span style="color:#ffffff; font-size:16px; font-weight:700;">🐄 Gestão de Rebanho</span>
              </td>
            </tr>
            <tr>
              <td style="padding:36px 32px 8px;">
                <h1 style="margin:0 0 16px; font-size:20px; font-weight:800; color:#18181b;">${opts.titulo}</h1>
                ${opts.corpoHtml}
              </td>
            </tr>
            <tr>
              <td align="center" style="padding:0 32px 30px;">
                <a href="${opts.link}" style="display:inline-block; background-color:#c8a84b; color:#04100a; font-size:14px; font-weight:700; text-decoration:none; padding:13px 32px; border-radius:100px;">
                  ${opts.botaoLabel}
                </a>
              </td>
            </tr>
            <tr>
              <td style="padding:0 32px 32px;">
                <p style="margin:16px 0 0; font-size:12px; line-height:1.6; color:#a1a1aa; word-break:break-all;">
                  Se o botão não funcionar, copie e cole este link no navegador:<br />
                  <a href="${opts.link}" style="color:#2a6b33;">${opts.link}</a>
                </p>
              </td>
            </tr>
            <tr>
              <td style="padding:18px 32px; background-color:#faf8f4; border-top:1px solid #e4e0d8;">
                <p style="margin:0; font-size:11.5px; color:#a1a1aa;">
                  Gestão de Rebanho — gestão pecuária para o produtor rural brasileiro.
                </p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>
  `.trim();
}

function templateResetSenha(nome: string, linkReset: string): string {
  const nomeSeguro = escaparHtml(nome);
  return envolverEmail({
    titulo: "Redefinir sua senha",
    corpoHtml: `
      <p style="margin:0 0 14px; font-size:14px; line-height:1.7; color:#3f3f46;">Olá, ${nomeSeguro}.</p>
      <p style="margin:0 0 26px; font-size:14px; line-height:1.7; color:#3f3f46;">
        Recebemos um pedido para redefinir a senha da sua conta no Gestão de Rebanho.
        Clique no botão abaixo para escolher uma nova senha. Este link expira em 1 hora — se você não pediu essa
        redefinição, pode ignorar este e-mail com segurança.
      </p>
    `,
    botaoLabel: "Escolher nova senha",
    link: linkReset,
  });
}

function textoResetSenha(nome: string, linkReset: string): string {
  return `Olá, ${nome}.\n\nRecebemos um pedido para redefinir a senha da sua conta no Gestão de Rebanho.\n\nAcesse o link abaixo para escolher uma nova senha:\n${linkReset}\n\nEste link expira em 1 hora. Se você não pediu essa redefinição, ignore este e-mail.`;
}

function templateVerificacaoEmail(nome: string, linkVerificacao: string): string {
  const nomeSeguro = escaparHtml(nome);
  return envolverEmail({
    titulo: "Confirme seu e-mail",
    corpoHtml: `
      <p style="margin:0 0 14px; font-size:14px; line-height:1.7; color:#3f3f46;">Olá, ${nomeSeguro}.</p>
      <p style="margin:0 0 26px; font-size:14px; line-height:1.7; color:#3f3f46;">
        Falta pouco para começar a usar o Gestão de Rebanho. Clique no botão abaixo para confirmar seu e-mail.
        Este link expira em 24 horas.
      </p>
    `,
    botaoLabel: "Confirmar e-mail",
    link: linkVerificacao,
  });
}

function textoVerificacaoEmail(nome: string, linkVerificacao: string): string {
  return `Olá, ${nome}.\n\nFalta pouco para começar a usar o Gestão de Rebanho. Acesse o link abaixo para confirmar seu e-mail:\n${linkVerificacao}\n\nEste link expira em 24 horas.`;
}

export const emailService = {
  async enviarResetSenha(destinatario: string, nome: string, linkReset: string) {
    const resend = obterCliente();
    const { error } = await resend.emails.send({
      from: `Gestão de Rebanho <${env.resend.fromEmail}>`,
      to: destinatario,
      subject: "Redefinir sua senha — Gestão de Rebanho",
      html: templateResetSenha(nome, linkReset),
      text: textoResetSenha(nome, linkReset),
    });
    if (error) {
      logger.error({ error }, "Falha ao enviar e-mail de reset de senha");
      throw new AppError(502, "email_falhou", "Nao foi possivel enviar o e-mail de redefinicao");
    }
  },

  async enviarVerificacaoEmail(destinatario: string, nome: string, linkVerificacao: string) {
    const resend = obterCliente();
    const { error } = await resend.emails.send({
      from: `Gestão de Rebanho <${env.resend.fromEmail}>`,
      to: destinatario,
      subject: "Confirme seu e-mail — Gestão de Rebanho",
      html: templateVerificacaoEmail(nome, linkVerificacao),
      text: textoVerificacaoEmail(nome, linkVerificacao),
    });
    if (error) {
      logger.error({ error }, "Falha ao enviar e-mail de verificacao");
      throw new AppError(502, "email_falhou", "Nao foi possivel enviar o e-mail de verificacao");
    }
  },
};
