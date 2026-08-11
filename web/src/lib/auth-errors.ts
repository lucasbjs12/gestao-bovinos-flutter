export function traduzirErroCadastro(code: string): string {
  const mapa: Record<string, string> = {
    "auth/email-already-in-use": "Este e-mail já está cadastrado.",
    "auth/invalid-email": "E-mail inválido.",
    "auth/weak-password": "A senha deve ter pelo menos 6 caracteres.",
    "auth/network-request-failed": "Sem conexão com a internet.",
  };
  return mapa[code] ?? "Erro ao criar a conta. Tente novamente.";
}
