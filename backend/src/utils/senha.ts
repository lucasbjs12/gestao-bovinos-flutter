import bcrypt from "bcryptjs";

const CUSTO_HASH = 12;

export function hashSenha(senha: string): Promise<string> {
  return bcrypt.hash(senha, CUSTO_HASH);
}

export function compararSenha(senha: string, hash: string): Promise<boolean> {
  return bcrypt.compare(senha, hash);
}
