"use client";

import { useEffect, useState } from "react";
import {
  Search,
  Ban,
  ShieldAlert,
} from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import {
  listarUsuarios,
  statusEfetivo,
  ativarUsuario,
  bloquearUsuario,
  Usuario,
  Plano,
  DURACAO_PLANO_DIAS,
  LABEL_PLANO,
} from "@/lib/admin";
import { PageHeader } from "@/components/ui/PageHeader";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Badge } from "@/components/ui/Badge";
import { EmptyState, Spinner } from "@/components/ui/EmptyState";

const TONE_STATUS: Record<string, "green" | "gold" | "red" | "gray"> = {
  ativo: "green",
  pendente: "gold",
  bloqueado: "red",
  vencido: "red",
};

const LABEL_STATUS: Record<string, string> = {
  ativo: "Ativo",
  pendente: "Pendente",
  bloqueado: "Bloqueado",
  vencido: "Vencido",
};

function diasRestantes(vencimento?: { toMillis: () => number } | null) {
  if (!vencimento) return null;
  return Math.ceil((vencimento.toMillis() - Date.now()) / (24 * 60 * 60 * 1000));
}

export default function PainelAdminPage() {
  const { user, isAdmin } = useAuth();
  const permitido = user ? isAdmin : null;
  const [usuarios, setUsuarios] = useState<Usuario[] | null>(null);
  const [busca, setBusca] = useState("");
  const [modalAtivar, setModalAtivar] = useState<Usuario | null>(null);
  const [plano, setPlano] = useState<Plano>("mensal");
  const [vencimentoManual, setVencimentoManual] = useState("");
  const [processando, setProcessando] = useState(false);

  async function carregar() {
    setUsuarios(await listarUsuarios());
  }

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    if (permitido) carregar();
  }, [permitido]);

  function abrirAtivar(u: Usuario) {
    setModalAtivar(u);
    setPlano("mensal");
    const venc = new Date();
    venc.setDate(venc.getDate() + DURACAO_PLANO_DIAS.mensal);
    setVencimentoManual(venc.toISOString().slice(0, 10));
  }

  function aoTrocarPlano(novo: Plano) {
    setPlano(novo);
    const venc = new Date();
    venc.setDate(venc.getDate() + DURACAO_PLANO_DIAS[novo]);
    setVencimentoManual(venc.toISOString().slice(0, 10));
  }

  async function confirmarAtivar() {
    if (!modalAtivar) return;
    setProcessando(true);
    try {
      await ativarUsuario(modalAtivar.uid, plano, new Date(vencimentoManual));
      setModalAtivar(null);
      carregar();
    } finally {
      setProcessando(false);
    }
  }

  async function bloquear(u: Usuario) {
    if (!confirm(`Bloquear o acesso de ${u.nome || u.email}?`)) return;
    await bloquearUsuario(u.uid);
    carregar();
  }

  if (permitido === null) {
    return (
      <Card>
        <Spinner />
      </Card>
    );
  }

  if (!permitido) {
    return (
      <div className="max-w-md mx-auto mt-16 text-center">
        <div className="w-14 h-14 rounded-2xl bg-danger-bg flex items-center justify-center text-danger mx-auto mb-5">
          <ShieldAlert size={26} />
        </div>
        <h1 className="font-display text-xl font-semibold text-text mb-2">
          Acesso restrito
        </h1>
        <p className="text-sm text-muted">
          Esta área é exclusiva para administradores do sistema.
        </p>
      </div>
    );
  }

  const filtrados = (usuarios ?? []).filter((u) => {
    const alvo = `${u.nome ?? ""} ${u.email ?? ""}`.toLowerCase();
    return alvo.includes(busca.toLowerCase());
  });

  return (
    <div>
      <PageHeader
        title="Painel admin"
        subtitle={usuarios ? `${usuarios.length} contas cadastradas` : undefined}
        action={
          <div className="relative">
            <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-2" />
            <input
              placeholder="Buscar por nome ou e-mail…"
              value={busca}
              onChange={(e) => setBusca(e.target.value)}
              className="field !pl-9 min-w-[260px]"
            />
          </div>
        }
      />

      <Card className="overflow-hidden">
        {usuarios === null && <Spinner />}
        {usuarios !== null && filtrados.length === 0 && (
          <EmptyState icon={<Search size={22} />} title="Nenhuma conta encontrada" />
        )}
        <div className="divide-y divide-border-soft">
          {filtrados.map((u) => {
            const status = statusEfetivo(u);
            const dias = diasRestantes(u.vencimento);
            return (
              <div key={u.uid} className="flex items-center justify-between gap-4 px-5 py-4">
                <div className="min-w-0">
                  <div className="flex items-center gap-2 mb-1">
                    <span className="text-sm font-semibold text-text truncate">
                      {u.nome || u.email || u.uid}
                    </span>
                    {u.isAdmin && <Badge tone="blue">Admin</Badge>}
                    <Badge tone={TONE_STATUS[status]}>{LABEL_STATUS[status]}</Badge>
                  </div>
                  <div className="text-xs text-muted truncate">
                    {u.email}
                    {status === "ativo" && dias != null && !u.isAdmin && (
                      <span className={dias <= 7 ? "text-warning font-semibold" : ""}>
                        {" "}
                        · Vence em {dias} dia{dias === 1 ? "" : "s"}
                      </span>
                    )}
                    {u.plano && !u.isAdmin && ` · ${LABEL_PLANO[u.plano as Plano] ?? u.plano}`}
                  </div>
                </div>
                <div className="flex items-center gap-1 shrink-0">
                  <Button size="sm" variant="secondary" onClick={() => abrirAtivar(u)}>
                    Ativar/Renovar
                  </Button>
                  <button
                    onClick={() => bloquear(u)}
                    className="p-2 rounded-md text-muted-2 hover:text-danger hover:bg-danger-bg transition-colors"
                    aria-label="Bloquear"
                    title="Bloquear"
                  >
                    <Ban size={15} />
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      </Card>

      {modalAtivar && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-40 p-4">
          <Card className="w-full max-w-sm p-6">
            <h2 className="font-display text-lg font-semibold text-text mb-1">
              Ativar/Renovar
            </h2>
            <p className="text-xs text-muted mb-4">
              {modalAtivar.nome || modalAtivar.email}
            </p>
            <label className="flex flex-col gap-1.5 mb-4">
              <span className="text-xs font-semibold text-text">Plano</span>
              <select
                value={plano}
                onChange={(e) => aoTrocarPlano(e.target.value as Plano)}
                className="field"
              >
                {(Object.keys(LABEL_PLANO) as Plano[]).map((p) => (
                  <option key={p} value={p}>
                    {LABEL_PLANO[p]}
                  </option>
                ))}
              </select>
            </label>
            <label className="flex flex-col gap-1.5 mb-5">
              <span className="text-xs font-semibold text-text">Vencimento</span>
              <input
                type="date"
                value={vencimentoManual}
                onChange={(e) => setVencimentoManual(e.target.value)}
                className="field"
              />
            </label>
            <div className="flex gap-3">
              <Button loading={processando} onClick={confirmarAtivar} className="flex-1">
                Confirmar
              </Button>
              <Button variant="secondary" onClick={() => setModalAtivar(null)}>
                Cancelar
              </Button>
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}
