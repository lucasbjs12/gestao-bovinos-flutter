import { API_BASE_URL } from "./backend-config";
import { ApiException } from "./api-exception";
import { tokenStorage } from "./token-storage";

/// Cliente HTTP fino para o backend próprio. Decodifica o envelope padrão
/// (`{success, message, data}`) e converte erro em [ApiException].
///
/// Faz refresh automático de token em 401: o access token dura só 15
/// minutos (`JWT_ACCESS_EXPIRES_IN` no backend), então qualquer sessão de
/// uso mais longa que isso bateria nisso o tempo todo se cada tela tivesse
/// que tratar na mão. Chamadas concorrentes compartilham a mesma renovação
/// em andamento (não dispara duas ao mesmo tempo -- o backend rotaciona o
/// refresh token a cada uso, então a segunda invalidaria a primeira).
let refreshEmAndamento: Promise<string | null> | null = null;

async function fazerRefresh(): Promise<string | null> {
  const refreshToken = tokenStorage.lerRefreshToken();
  if (!refreshToken) return null;

  try {
    const resposta = await fetch(`${API_BASE_URL}/auth/refresh`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ refreshToken }),
    });
    const corpo = await resposta.json();
    if (!corpo.success) throw new Error(corpo.message ?? "refresh falhou");
    const dados = corpo.data as { accessToken: string; refreshToken: string };
    tokenStorage.salvar(dados.accessToken, dados.refreshToken);
    return dados.accessToken;
  } catch {
    // Refresh token também inválido/expirado -- sessão morreu de vez. Limpa
    // pra não ficar tentando renovar com um token morto a cada chamada (o
    // auth-context percebe no próximo /me e desloga).
    tokenStorage.limpar();
    return null;
  }
}

function renovarToken(): Promise<string | null> {
  if (!refreshEmAndamento) {
    refreshEmAndamento = fazerRefresh().finally(() => {
      refreshEmAndamento = null;
    });
  }
  return refreshEmAndamento;
}

async function enviar(
  metodo: string,
  caminho: string,
  {
    corpo,
    autenticado = true,
    tentandoNovamente = false,
  }: { corpo?: unknown; autenticado?: boolean; tentandoNovamente?: boolean } = {}
): Promise<unknown> {
  const headers: Record<string, string> = { "Content-Type": "application/json" };

  if (autenticado) {
    const token = tokenStorage.lerAccessToken();
    if (token) headers["Authorization"] = `Bearer ${token}`;
  }

  const resposta = await fetch(`${API_BASE_URL}${caminho}`, {
    method: metodo,
    headers,
    body: corpo === undefined ? undefined : JSON.stringify(corpo),
  });

  // Access token expirado: tenta renovar (uma vez só, pra não entrar em
  // loop) e repete a mesma chamada com o token novo.
  if (autenticado && resposta.status === 401 && !tentandoNovamente) {
    const novoToken = await renovarToken();
    if (novoToken) {
      return enviar(metodo, caminho, { corpo, autenticado, tentandoNovamente: true });
    }
  }

  if (resposta.status === 204) return null;

  let corpoResposta: { success?: boolean; message?: string; data?: unknown; error?: unknown };
  try {
    corpoResposta = await resposta.json();
  } catch {
    throw new ApiException(resposta.status, `Resposta inválida do servidor (status ${resposta.status})`);
  }

  if (!corpoResposta.success) {
    const erro = corpoResposta.error;
    const codigo = erro && typeof erro === "object" ? (erro as { code?: string }).code : undefined;
    throw new ApiException(resposta.status, corpoResposta.message ?? "Erro desconhecido", codigo);
  }

  return corpoResposta.data;
}

export const api = {
  get: (caminho: string, opts?: { autenticado?: boolean }) =>
    enviar("GET", caminho, opts),
  post: (caminho: string, corpo?: unknown, opts?: { autenticado?: boolean }) =>
    enviar("POST", caminho, { corpo, ...opts }),
  put: (caminho: string, corpo?: unknown, opts?: { autenticado?: boolean }) =>
    enviar("PUT", caminho, { corpo, ...opts }),
  patch: (caminho: string, corpo?: unknown, opts?: { autenticado?: boolean }) =>
    enviar("PATCH", caminho, { corpo, ...opts }),
  delete: (caminho: string, opts?: { autenticado?: boolean }) =>
    enviar("DELETE", caminho, opts),
};
