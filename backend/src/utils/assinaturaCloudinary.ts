import crypto from "node:crypto";

/**
 * Implementa o algoritmo de assinatura do upload direto da Cloudinary:
 * SHA-1 de "param1=valor1&param2=valor2...&api_secret" com os parametros em
 * ordem alfabetica (sem incluir file/api_key/cloud_name/resource_type na assinatura).
 * https://cloudinary.com/documentation/signatures
 */
export function assinarParametrosCloudinary(
  parametros: Record<string, string | number>,
  apiSecret: string,
): string {
  const paraAssinar = Object.keys(parametros)
    .sort()
    .map((chave) => `${chave}=${parametros[chave]}`)
    .join("&");

  return crypto
    .createHash("sha1")
    .update(paraAssinar + apiSecret)
    .digest("hex");
}
