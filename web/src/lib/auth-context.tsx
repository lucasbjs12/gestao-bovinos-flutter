"use client";

import {
  createContext,
  useContext,
  useEffect,
  useState,
  ReactNode,
  useCallback,
} from "react";
import { backendAuth, UsuarioBackend, FazendaBackend } from "./backend-auth";
import { tokenStorage } from "./token-storage";
import { ApiException } from "./api-exception";

/// Usuário autenticado, no formato enxuto usado pelas telas (mesmos campos
/// que o Firebase `User` expunha, pra minimizar mudanças nas páginas).
export interface AuthUser {
  uid: string;
  email: string;
  displayName: string | null;
}

interface AuthState {
  user: AuthUser | null;
  loading: boolean;
  isAdmin: boolean;
  fazendaId: string | null;
  souDono: boolean;
  ehConvidado: boolean;
  logout: () => Promise<void>;
  entrarNaFazenda: (fazendaId: string, nome?: string) => void;
  recarregar: () => Promise<void>;
  fazendasVinculadas: () => { id: string; nome: string }[];
}

const AuthContext = createContext<AuthState>({
  user: null,
  loading: true,
  isAdmin: false,
  fazendaId: null,
  souDono: true,
  ehConvidado: false,
  logout: async () => {},
  entrarNaFazenda: () => {},
  recarregar: async () => {},
  fazendasVinculadas: () => [],
});

const FAZENDA_ATIVA_KEY = "fazenda_ativa";
const VINCULOS_KEY = "vinculos_fazenda";

function paraAuthUser(usuario: UsuarioBackend): AuthUser {
  return { uid: usuario.id, email: usuario.email, displayName: usuario.nome };
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [loading, setLoading] = useState(true);
  const [fazendaPropria, setFazendaPropria] = useState<FazendaBackend | null>(null);
  const [fazendaId, setFazendaId] = useState<string | null>(null);

  const carregarSessao = useCallback(async () => {
    if (!backendAuth.estaLogado()) {
      setUser(null);
      setIsAdmin(false);
      setFazendaPropria(null);
      setFazendaId(null);
      setLoading(false);
      return;
    }

    async function buscarPerfil() {
      const { usuario, fazendaPropria: fazenda } = await backendAuth.me();
      setUser(paraAuthUser(usuario));
      setIsAdmin(usuario.isAdmin);
      setFazendaPropria(fazenda);
      const salva =
        typeof window !== "undefined"
          ? window.localStorage.getItem(`${FAZENDA_ATIVA_KEY}_${usuario.id}`)
          : null;
      setFazendaId(salva || fazenda?.id || null);
    }

    try {
      await buscarPerfil();
    } catch (err) {
      if (err instanceof ApiException && err.statusCode === 401) {
        const sessao = await backendAuth.refresh().catch(() => null);
        if (sessao) {
          await buscarPerfil();
        } else {
          tokenStorage.limpar();
          setUser(null);
          setIsAdmin(false);
          setFazendaPropria(null);
          setFazendaId(null);
        }
      } else {
        setUser(null);
        setIsAdmin(false);
        setFazendaPropria(null);
        setFazendaId(null);
      }
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    carregarSessao();
  }, [carregarSessao]);

  const souDono = !!user && fazendaId === fazendaPropria?.id;
  const ehConvidado = !!user && !souDono;

  const logout = async () => {
    await backendAuth.logout();
    setUser(null);
    setIsAdmin(false);
    setFazendaPropria(null);
    setFazendaId(null);
  };

  const entrarNaFazenda = (novoFazendaId: string, nome?: string) => {
    if (!user) return;
    window.localStorage.setItem(`${FAZENDA_ATIVA_KEY}_${user.uid}`, novoFazendaId);
    setFazendaId(novoFazendaId);

    if (novoFazendaId !== fazendaPropria?.id) {
      const chave = `${VINCULOS_KEY}_${user.uid}`;
      const atuais: { id: string; nome: string }[] = JSON.parse(
        window.localStorage.getItem(chave) ?? "[]"
      );
      const semEsta = atuais.filter((v) => v.id !== novoFazendaId);
      semEsta.push({ id: novoFazendaId, nome: nome ?? "" });
      window.localStorage.setItem(chave, JSON.stringify(semEsta));
    }
  };

  const fazendasVinculadas = () => {
    if (!user) return [];
    const chave = `${VINCULOS_KEY}_${user.uid}`;
    return JSON.parse(window.localStorage.getItem(chave) ?? "[]");
  };

  const recarregar = async () => {
    await carregarSessao();
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        loading,
        isAdmin,
        fazendaId,
        souDono,
        ehConvidado,
        logout,
        entrarNaFazenda,
        recarregar,
        fazendasVinculadas,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}
