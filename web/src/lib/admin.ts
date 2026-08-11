import { adminApi, StatusAssinatura, UsuarioAdmin } from "./api/admin";

export type StatusUsuario = StatusAssinatura;
export type Plano = "mensal" | "trimestral" | "semestral" | "anual";

export const DURACAO_PLANO_DIAS: Record<Plano, number> = {
  mensal: 30,
  trimestral: 90,
  semestral: 180,
  anual: 365,
};

export const LABEL_PLANO: Record<Plano, string> = {
  mensal: "Mensal",
  trimestral: "Trimestral",
  semestral: "Semestral",
  anual: "Anual",
};

/// Formato "tipo Timestamp" só pra manter a UI (diasRestantes) igual à
/// versão Firestore, sem reescrever quem consome isso.
export interface Vencimento {
  toMillis: () => number;
}

export interface Usuario {
  uid: string;
  nome?: string;
  email?: string;
  isAdmin: boolean;
  status: string;
  plano?: string;
  vencimento?: Vencimento | null;
  criadoEm?: string;
}

function paraUsuario(u: UsuarioAdmin): Usuario {
  return {
    uid: u.id,
    nome: u.nome,
    email: u.email,
    isAdmin: u.isAdmin,
    status: u.statusAssinatura,
    plano: u.plano ?? undefined,
    vencimento: u.vencimento ? { toMillis: () => new Date(u.vencimento!).getTime() } : null,
    criadoEm: u.criadoEm,
  };
}

/// Espelha UsuarioAssinatura.statusEfetivo do app: admin sempre conta como
/// ativo; bloqueado explícito prevalece; ativo com vencimento passado vira
/// "vencido" automaticamente (calculado no cliente, sem job de servidor).
export function statusEfetivo(u: Usuario): StatusUsuario {
  if (u.isAdmin) return "ativo";
  if (u.status === "bloqueado") return "bloqueado";
  if (u.status === "ativo" && u.vencimento && u.vencimento.toMillis() < Date.now()) {
    return "vencido";
  }
  return (u.status as StatusUsuario) ?? "pendente";
}

export async function listarUsuarios(): Promise<Usuario[]> {
  const { itens } = await adminApi.listarUsuarios({ pageSize: 100 });
  return itens.map(paraUsuario);
}

export async function ativarUsuario(uid: string, plano: Plano, vencimento: Date) {
  await adminApi.atualizarAssinatura(uid, {
    statusAssinatura: "ativo",
    plano,
    vencimento: vencimento.toISOString().slice(0, 10),
  });
}

export async function bloquearUsuario(uid: string) {
  await adminApi.atualizarAssinatura(uid, { statusAssinatura: "bloqueado" });
}
