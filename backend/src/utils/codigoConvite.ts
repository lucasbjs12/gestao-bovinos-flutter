import crypto from "node:crypto";

// Sem 0/O/1/I para evitar confusao ao digitar/ler o codigo em voz alta.
const ALFABETO = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";

export function gerarCodigoConvite(): string {
  let sufixo = "";
  for (let i = 0; i < 6; i += 1) {
    const indice = crypto.randomInt(0, ALFABETO.length);
    sufixo += ALFABETO[indice];
  }
  return `BOV-${sufixo}`;
}
