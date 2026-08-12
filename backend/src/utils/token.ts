import crypto from "node:crypto";
import jwt from "jsonwebtoken";
import { env } from "../config/env";

export interface AccessTokenPayload {
  sub: string;
  isAdmin: boolean;
  nome: string;
}

export function gerarAccessToken(payload: AccessTokenPayload): string {
  return jwt.sign(payload, env.jwt.accessSecret, {
    expiresIn: env.jwt.accessExpiresIn as jwt.SignOptions["expiresIn"],
  });
}

export function verificarAccessToken(token: string): AccessTokenPayload {
  return jwt.verify(token, env.jwt.accessSecret) as AccessTokenPayload;
}

export function gerarRefreshTokenBruto(): string {
  return crypto.randomBytes(48).toString("hex");
}

export function hashRefreshToken(tokenBruto: string): string {
  return crypto.createHash("sha256").update(tokenBruto).digest("hex");
}

export function calcularExpiracaoRefreshToken(): Date {
  const dias = env.jwt.refreshExpiresInDays;
  return new Date(Date.now() + dias * 24 * 60 * 60 * 1000);
}

export function gerarResetTokenBruto(): string {
  return crypto.randomBytes(32).toString("hex");
}

export function hashResetToken(tokenBruto: string): string {
  return crypto.createHash("sha256").update(tokenBruto).digest("hex");
}

export function calcularExpiracaoResetToken(): Date {
  return new Date(Date.now() + 60 * 60 * 1000);
}

export function calcularExpiracaoVerificacaoEmail(): Date {
  return new Date(Date.now() + 24 * 60 * 60 * 1000);
}
