import "dotenv/config";

function obrigatoria(nome: string): string {
  const valor = process.env[nome];
  if (!valor) {
    throw new Error(`Variavel de ambiente ${nome} nao definida`);
  }
  return valor;
}

export const env = {
  nodeEnv: process.env.NODE_ENV ?? "development",
  port: Number(process.env.PORT ?? 3000),
  databaseUrl: obrigatoria("DATABASE_URL"),
  jwt: {
    accessSecret: obrigatoria("JWT_ACCESS_SECRET"),
    accessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN ?? "15m",
    refreshExpiresInDays: Number(process.env.JWT_REFRESH_EXPIRES_IN_DAYS ?? 30),
  },
  // Aceita uma ou mais origens separadas por virgula (ex: dominio raiz e
  // www, que sao origens distintas para o navegador mesmo com um
  // redirecionando pro outro).
  corsOrigins: (process.env.CORS_ORIGIN ?? "*").split(",").map((o) => o.trim()),
  frontendUrl: process.env.FRONTEND_URL ?? "http://localhost:3001",
  cloudinary: {
    cloudName: process.env.CLOUDINARY_CLOUD_NAME,
    apiKey: process.env.CLOUDINARY_API_KEY,
    apiSecret: process.env.CLOUDINARY_API_SECRET,
  },
  resend: {
    apiKey: process.env.RESEND_API_KEY,
    fromEmail: process.env.RESEND_FROM_EMAIL ?? "onboarding@resend.dev",
  },
  rateLimit: {
    windowMs: Number(process.env.RATE_LIMIT_WINDOW_MS ?? 900_000),
    max: Number(process.env.RATE_LIMIT_MAX ?? 100),
  },
  mercadoPago: {
    accessToken: process.env.MERCADOPAGO_ACCESS_TOKEN,
    // Assina a notificacao do webhook -- painel do Mercado Pago em
    // Suas integracoes > (app) > Webhooks > Assinatura secreta.
    webhookSecret: process.env.MERCADOPAGO_WEBHOOK_SECRET,
  },
};
