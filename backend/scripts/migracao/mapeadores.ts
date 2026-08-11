import { CategoriaBovino, MotivoBaixa, TipoEventoSanitario } from "@prisma/client";

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function ehUuidValido(valor: unknown): valor is string {
  return typeof valor === "string" && UUID_REGEX.test(valor);
}

/** Registros antigos podem ter motivo como texto livre digitado a mao. */
export function normalizarMotivoBaixa(valor: unknown): MotivoBaixa {
  const texto = String(valor ?? "").trim().toLowerCase();
  if (texto.startsWith("morte")) return MotivoBaixa.Morte;
  if (texto.startsWith("venda")) return MotivoBaixa.Venda;
  if (texto.startsWith("furto") || texto.startsWith("roubo")) return MotivoBaixa.Furto;
  return MotivoBaixa.Outros;
}

/** O app Flutter usa rotulos acentuados; o enum do Postgres e ASCII. */
export function normalizarTipoEvento(valor: unknown): TipoEventoSanitario {
  const REMOVER_DIACRITICOS = new RegExp("[\\u0300-\\u036f]", "g");
  const texto = String(valor ?? "")
    .normalize("NFD")
    .replace(REMOVER_DIACRITICOS, "") // remove acentos (diacriticos combinantes)
    .trim()
    .toLowerCase();
  const mapa: Record<string, TipoEventoSanitario> = {
    vacinacao: TipoEventoSanitario.Vacinacao,
    vermifugacao: TipoEventoSanitario.Vermifugacao,
    medicacao: TipoEventoSanitario.Medicacao,
    castracao: TipoEventoSanitario.Castracao,
    banho: TipoEventoSanitario.Banho,
  };
  return mapa[texto] ?? TipoEventoSanitario.Outros;
}

const CATEGORIAS_VALIDAS = new Set(Object.values(CategoriaBovino));

/** Categoria era string livre no Firestore; sem correspondencia exata cai pra "Outros"-like (Boi). */
export function normalizarCategoria(valor: unknown): CategoriaBovino {
  const texto = String(valor ?? "").trim();
  if ((CATEGORIAS_VALIDAS as Set<string>).has(texto)) {
    return texto as CategoriaBovino;
  }
  return CategoriaBovino.Boi;
}

/** Firestore guarda millis (numero) e/ou string de exibicao; preferimos millis. */
export function converterData(millis: unknown, textoFallback?: unknown): Date | undefined {
  if (typeof millis === "number" && Number.isFinite(millis)) {
    return new Date(millis);
  }
  if (typeof textoFallback === "string" && textoFallback.trim()) {
    const data = new Date(textoFallback);
    if (!Number.isNaN(data.getTime())) return data;
  }
  return undefined;
}

/** Timestamp do Firestore (tem .toDate()) ou ja um Date/string/number. */
export function converterTimestamp(valor: unknown): Date | undefined {
  if (!valor) return undefined;
  if (typeof valor === "object" && valor !== null && "toDate" in valor) {
    return (valor as { toDate: () => Date }).toDate();
  }
  if (valor instanceof Date) return valor;
  if (typeof valor === "number") return new Date(valor);
  if (typeof valor === "string") {
    const data = new Date(valor);
    if (!Number.isNaN(data.getTime())) return data;
  }
  return undefined;
}
