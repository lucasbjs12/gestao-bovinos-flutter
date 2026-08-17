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
  bloquearUsuario,
  ativarPlanoNovo,
  Usuario,
} from "@/lib/admin";
import {
  planosApi,
  Plano as PlanoNovo,
  valorReais,
  valorMensalEquivalente,
  formatarReais,
} from "@/lib/api/planos";
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
  const [planosDisponiveis, setPlanosDisponiveis] = useState<PlanoNovo[]>([]);
  const [planoNovoId, setPlanoNovoId] = useState("");
  const [vencimentoManual, setVencimentoManual] = useState("");
  const [processando, setProcessando] = useState(false);

  async function carregar() {
    setUsuarios(await listarUsuarios());
  }

  useEffect(() => {
    if (!permitido) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect
    carregar();
    planosApi.listar().then((todos) => setPlanosDisponiveis(todos.filter((p) => p.valorCentavos > 0)));
  }, [permitido]);

  /// Data padrão de próxima cobrança conforme a periodicidade do plano --
  /// mensal soma 30 dias, anual soma 365. O admin ainda pode ajustar a mão
  /// depois, isso só preenche um valor sensato ao trocar de plano.
  function dataPadraoPara(planoId: string): string {
    const p = planosDisponiveis.find((x) => x.id === planoId);
    const venc = new Date();
    venc.setDate(venc.getDate() + (p?.periodicidade === "anual" ? 365 : 30));
    return venc.toISOString().slice(0, 10);
  }

  function aoTrocarPlanoNovo(id: string) {
    setPlanoNovoId(id);
    setVencimentoManual(dataPadraoPara(id));
  }

  function abrirAtivar(u: Usuario) {
    setModalAtivar(u);
    const idInicial = u.assinatura?.plano?.id ?? planosDisponiveis[0]?.id ?? "";
    setPlanoNovoId(idInicial);
    setVencimentoManual(dataPadraoPara(idInicial));
  }

  async function confirmarAtivar() {
    if (!modalAtivar || !planoNovoId) return;
    setProcessando(true);
    try {
      await ativarPlanoNovo(modalAtivar.uid, planoNovoId, new Date(vencimentoManual));
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
                    {u.assinatura?.plano && (
                      <Badge tone="gold">{u.assinatura.plano.nome}</Badge>
                    )}
                  </div>
                  <div className="text-xs text-muted truncate">
                    {u.email}
                    {status === "ativo" && dias != null && !u.isAdmin && (
                      <span className={dias <= 7 ? "text-warning font-semibold" : ""}>
                        {" "}
                        · Vence em {dias} dia{dias === 1 ? "" : "s"}
                      </span>
                    )}
                    {u.assinatura?.plano && u.assinatura.proximaCobranca && (
                      <> · Plano até {new Date(u.assinatura.proximaCobranca).toLocaleDateString("pt-BR")}</>
                    )}
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
                value={planoNovoId}
                onChange={(e) => aoTrocarPlanoNovo(e.target.value)}
                className="field"
              >
                {planosDisponiveis.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.nome} · {p.periodicidade === "anual" ? "Anual" : "Mensal"} · R${" "}
                    {formatarReais(valorMensalEquivalente(p))}/mês
                    {p.periodicidade === "anual" ? ` (R$ ${formatarReais(valorReais(p))}/ano)` : ""}
                  </option>
                ))}
              </select>
            </label>
            <label className="flex flex-col gap-1.5 mb-5">
              <span className="text-xs font-semibold text-text">Próxima cobrança</span>
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
