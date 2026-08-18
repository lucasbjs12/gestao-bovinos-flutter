import type { CorDestaque } from "./api/bovinos";

// Mesma paleta e mesmos hex do app Flutter (lib/core/widgets/cor_destaque.dart)
// -- mantém o visual consistente entre app e site pro mesmo destaque.
export const CORES_DESTAQUE: Record<CorDestaque, string> = {
  amarelo: "#F2C230",
  azul: "#3B82F6",
  verde: "#22A55A",
  vermelho: "#E0453D",
  roxo: "#8B5CF6",
  laranja: "#F2822F",
};

export const NOMES_DESTAQUE: Record<CorDestaque, string> = {
  amarelo: "Amarelo",
  azul: "Azul",
  verde: "Verde",
  vermelho: "Vermelho",
  roxo: "Roxo",
  laranja: "Laranja",
};

export const CORES_DESTAQUE_LISTA = Object.keys(CORES_DESTAQUE) as CorDestaque[];
