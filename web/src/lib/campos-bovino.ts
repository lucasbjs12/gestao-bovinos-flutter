"use client";

export type CampoBovino =
  | "nomeAnimal"
  | "raca"
  | "pesoAtual"
  | "invernada"
  | "observacoes"
  | "codigoEpc";

export const CAMPOS_BOVINO: { campo: CampoBovino; label: string }[] = [
  { campo: "nomeAnimal", label: "Nome do animal" },
  { campo: "raca", label: "Raça" },
  { campo: "pesoAtual", label: "Peso atual" },
  { campo: "invernada", label: "Invernada" },
  { campo: "observacoes", label: "Observações" },
  { campo: "codigoEpc", label: "Código EPC (RFID)" },
];

function chave(campo: CampoBovino) {
  return `campo_bovino_${campo}`;
}

/// Igual ao app: default é sempre visível se nunca configurado. Aplicado
/// tanto no cadastro quanto na edição do bovino (no app só valia no cadastro
/// — inconsistência corrigida aqui).
export function campoVisivel(campo: CampoBovino): boolean {
  if (typeof window === "undefined") return true;
  const v = localStorage.getItem(chave(campo));
  return v === null ? true : v === "1";
}

export function salvarCampo(campo: CampoBovino, visivel: boolean) {
  localStorage.setItem(chave(campo), visivel ? "1" : "0");
}

export function restaurarPadrao() {
  CAMPOS_BOVINO.forEach(({ campo }) => localStorage.removeItem(chave(campo)));
}
