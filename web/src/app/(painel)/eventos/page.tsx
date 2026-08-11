"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Search, Plus, Syringe, Users2, Trash2 } from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { eventosApi, TipoEventoSanitario, EventoSanitario } from "@/lib/api/eventos";
import { buscarTodasPaginas } from "@/lib/api/pagination";
import { PageHeader } from "@/components/ui/PageHeader";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Badge } from "@/components/ui/Badge";
import { EmptyState, Spinner } from "@/components/ui/EmptyState";

const LABEL_POR_TIPO: Record<TipoEventoSanitario, string> = {
  Vacinacao: "Vacinação",
  Vermifugacao: "Vermifugação",
  Medicacao: "Medicação",
  Castracao: "Castração",
  Banho: "Banho",
  Outros: "Outros",
};

const TONE_POR_TIPO: Record<TipoEventoSanitario, "green" | "gold" | "blue" | "red" | "gray"> = {
  Vacinacao: "green",
  Vermifugacao: "blue",
  Medicacao: "gold",
  Castracao: "red",
  Banho: "blue",
  Outros: "gray",
};

export default function EventosPage() {
  const { fazendaId, souDono } = useAuth();
  const router = useRouter();
  const [eventos, setEventos] = useState<EventoSanitario[] | null>(null);
  const [busca, setBusca] = useState("");

  async function carregar() {
    if (!fazendaId) return;
    const todosEventos = await buscarTodasPaginas((page) =>
      eventosApi.listar(fazendaId, { page, pageSize: 100 })
    );
    todosEventos.sort((a, b) => {
      const da = a.dataEvento ? new Date(a.dataEvento).getTime() : 0;
      const db = b.dataEvento ? new Date(b.dataEvento).getTime() : 0;
      return db - da;
    });
    setEventos(todosEventos);
  }

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    carregar();

    function aoRestaurarDoCache(e: PageTransitionEvent) {
      if (e.persisted) carregar();
    }
    window.addEventListener("pageshow", aoRestaurarDoCache);
    return () => window.removeEventListener("pageshow", aoRestaurarDoCache);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [fazendaId]);

  async function remover(id: string, tipo: TipoEventoSanitario) {
    if (!fazendaId) return;
    if (!confirm(`Excluir o evento de ${LABEL_POR_TIPO[tipo]}?`)) return;
    await eventosApi.excluir(fazendaId, id);
    carregar();
  }

  const filtrados = (eventos ?? []).filter((e) =>
    LABEL_POR_TIPO[e.tipo]?.toLowerCase().includes(busca.toLowerCase())
  );

  return (
    <div>
      <PageHeader
        title="Sanidade"
        subtitle={eventos ? `${eventos.length} eventos registrados` : undefined}
        action={
          <>
            <div className="relative">
              <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-2" />
              <input
                placeholder="Buscar por tipo…"
                value={busca}
                onChange={(e) => setBusca(e.target.value)}
                className="field !pl-9 min-w-[220px]"
              />
            </div>
            <Button href="/eventos/novo" icon={<Plus size={15} />}>
              Novo evento
            </Button>
          </>
        }
      />

      <Card className="overflow-hidden">
        {eventos === null && <Spinner />}

        {eventos !== null && filtrados.length === 0 && (
          <EmptyState
            icon={<Syringe size={22} />}
            title={eventos.length === 0 ? "Nenhum evento registrado" : "Nada encontrado"}
            description={
              eventos.length === 0
                ? "Registre o primeiro manejo sanitário do rebanho."
                : "Tente buscar por outro tipo de evento."
            }
            action={
              eventos.length === 0 ? (
                <Button href="/eventos/novo" size="sm" icon={<Plus size={14} />}>
                  Novo evento
                </Button>
              ) : undefined
            }
          />
        )}

        <div className="divide-y divide-border-soft">
          {filtrados.map((e) => (
            <div
              key={e.id}
              onClick={() => router.push(`/eventos/${e.id}`)}
              className="flex items-center justify-between gap-3 px-5 py-4 hover:bg-g50 cursor-pointer transition-colors"
            >
              <div className="min-w-0">
                <div className="flex items-center gap-2 mb-1">
                  <Badge tone={TONE_POR_TIPO[e.tipo] ?? "gray"}>{LABEL_POR_TIPO[e.tipo] ?? e.tipo}</Badge>
                  <span className="text-xs text-muted">{e.dataEvento ?? "sem data"}</span>
                </div>
                <div className="text-xs text-muted truncate">
                  {[e.produtoUtilizado, e.responsavel].filter(Boolean).join(" · ") || "—"}
                </div>
              </div>
              <div className="flex items-center gap-4 shrink-0">
                <span className="flex items-center gap-1.5 text-xs text-muted whitespace-nowrap">
                  <Users2 size={13} />
                  {e.bovinos?.length ?? 0}
                </span>
                {souDono && (
                  <button
                    onClick={(ev) => {
                      ev.stopPropagation();
                      remover(e.id, e.tipo);
                    }}
                    className="p-1.5 rounded-md text-muted-2 hover:text-danger hover:bg-danger-bg transition-colors"
                    aria-label="Excluir"
                  >
                    <Trash2 size={14} />
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
}
