import { api } from "./api-client";
import { tokenStorage } from "./token-storage";

export interface UsuarioBackend {
  id: string;
  nome: string;
  email: string;
  isAdmin: boolean;
  emailVerificado: boolean;
  statusAssinatura: string;
}

export interface FazendaBackend {
  id: string;
  nome: string;
  donoId: string;
}

export interface SessaoBackend {
  usuario: UsuarioBackend;
  fazenda?: FazendaBackend;
  accessToken: string;
  refreshToken: string;
}

function salvarSessao(dados: Record<string, unknown>): SessaoBackend {
  const sessao = dados as unknown as SessaoBackend;
  tokenStorage.salvar(sessao.accessToken, sessao.refreshToken);
  return sessao;
}

export const backendAuth = {
  async registrar(nome: string, email: string, senha: string, nomeFazenda?: string) {
    const dados = await api.post(
      "/auth/registro",
      { nome, email, senha, ...(nomeFazenda?.trim() ? { nomeFazenda } : {}) },
      { autenticado: false }
    );
    return salvarSessao(dados as Record<string, unknown>);
  },

  async login(email: string, senha: string) {
    const dados = await api.post("/auth/login", { email, senha }, { autenticado: false });
    return salvarSessao(dados as Record<string, unknown>);
  },

  /// Renova o access token usando o refresh token guardado. Retorna `null`
  /// se não houver refresh token salvo (usuário nunca logou por aqui).
  async refresh(): Promise<SessaoBackend | null> {
    const refreshTokenAtual = tokenStorage.lerRefreshToken();
    if (!refreshTokenAtual) return null;
    const dados = await api.post(
      "/auth/refresh",
      { refreshToken: refreshTokenAtual },
      { autenticado: false }
    );
    return salvarSessao(dados as Record<string, unknown>);
  },

  async logout() {
    const refreshTokenAtual = tokenStorage.lerRefreshToken();
    if (refreshTokenAtual) {
      try {
        await api.post("/auth/logout", { refreshToken: refreshTokenAtual }, { autenticado: false });
      } catch {
        // logout local sempre acontece, mesmo se a chamada falhar
      }
    }
    tokenStorage.limpar();
  },

  async esqueciSenha(email: string) {
    await api.post("/auth/esqueci-senha", { email }, { autenticado: false });
  },

  async redefinirSenha(token: string, novaSenha: string) {
    await api.post("/auth/redefinir-senha", { token, novaSenha }, { autenticado: false });
  },

  async verificarEmail(token: string) {
    await api.post("/auth/verificar-email", { token }, { autenticado: false });
  },

  async reenviarVerificacao() {
    await api.post("/auth/reenviar-verificacao", {});
  },

  async me(): Promise<{ usuario: UsuarioBackend; fazendaPropria: FazendaBackend | null }> {
    const dados = await api.get("/auth/me");
    return dados as { usuario: UsuarioBackend; fazendaPropria: FazendaBackend | null };
  },

  estaLogado(): boolean {
    return tokenStorage.lerAccessToken() !== null;
  },
};
