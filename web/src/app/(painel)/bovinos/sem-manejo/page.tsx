"use client";

import { useEffect, useMemo, useState } from "react";
import { ClockAlert, CheckCircle2 } from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { bovinosApi } from "@/lib/api/bovinos";
import { eventosApi } from "@/lib/api/eventos";
import { buscarTodasPaginas } from "@/lib/api/pagination";
import { PageHeader } from "@/components/ui/PageHeader";
import { Card } from "@/components/ui/Card";
import { Badge } from "@/components/ui/Badge";
import { EmptyState, Spinner } from "@/components/ui/EmptyState";

interface BovinoResumo {
  id: string;
  numeroBrinco: string;
  nomeAnimal?: string | null;
  categoria?: string | null;
  ultimoManejoMillis: number | null;
}

export default function SemManejoPage() {
  const { fazendaId } = useAuth();
  const [lista, setLista] = useState<BovinoResumo[] | null>(null);
  const [threshold, setThreshold] = useState(30);
  const [agora] = useState(() => Date.now());

  useEffect(() => {
    if (!fazendaId) return;
    async function carregar() {
      const [bovinosAtivos, todosEventos] = await Promise.all([
        buscarTodasPaginas((page) => bovinosApi.listar(fazendaId!, { page, pageSize: 100 })),
        buscarTodasPaginas((page) => eventosApi.listar(fazendaId!, { page, pageSize: 100 })),
      ]);

      const ultimoPorBovino = new Map<string, number>();
      todosEventos.forEach((e) => {
        if (!e.dataEvento) return;
        const millis = Date.parse(e.dataEvento);
        if (Number.isNaN(millis)) return;
        e.bovinos.forEach(({ bovinoId }) => {
          const atual = ultimoPorBovino.get(bovinoId) ?? 0;
          if (millis > atual) ultimoPorBovino.set(bovinoId, millis);
        });
      });

      setLista(
        bovinosAtivos
          .filter((b) => b.status === "Ativo")
          .map((b) => ({
            id: b.id,
            numeroBrinco: b.numeroBrinco,
            nomeAnimal: b.nomeAnimal,
            categoria: b.categoria,
            ultimoManejoMillis: ultimoPorBovino.get(b.id) ?? null,
          }))
      );
    }
    carregar();
  }, [fazendaId]);

  const filtrados = useMemo(() => {
    if (!lista) return [];
    const limite = agora - threshold * 24 * 60 * 60 * 1000;
    return lista.filter(
      (b) => b.ultimoManejoMillis === null || b.ultimoManejoMillis < limite
    );
  }, [lista, threshold, agora]);

  function diasLabel(millis: number | null) {
    if (millis === null) return "Nunca realizou manejo";
    const dias = Math.floor((agora - millis) / (24 * 60 * 60 * 1000));
    return `${dias} dias sem manejo`;
  }

  return (
    <div>
      <PageHeader
        title="Sem manejo"
        subtitle="Animais ativos sem nenhum evento sanitário no período"
        action={
          <div className="flex gap-1.5">
            {[30, 60, 90].map((t) => (
              <button
                key={t}
                onClick={() => setThreshold(t)}
                className={`px-3.5 py-1.5 rounded-lg text-xs font-semibold border transition-colors ${
                  threshold === t
                    ? "bg-g800 text-white border-g800"
                    : "border-border text-muted hover:bg-cream bg-surface"
                }`}
              >
                {t} dias
              </button>
            ))}
          </div>
        }
      />

      <Card className="overflow-hidden">
        {lista === null && <Spinner />}
        {lista !== null && filtrados.length === 0 && (
          <EmptyState
            icon={<CheckCircle2 size={22} />}
            title="Todos os animais estão em dia"
            description="Nenhum animal ativo passou do período selecionado sem manejo."
          />
        )}
        <div className="divide-y divide-border-soft">
          {filtrados.map((b) => (
            <div
              key={b.id}
              className="flex items-center justify-between px-5 py-3.5"
            >
              <div>
                <div className="text-sm font-semibold text-text">
                  <span className="font-mono">{b.numeroBrinco}</span>
                  {b.nomeAnimal ? ` · ${b.nomeAnimal}` : ""}
                </div>
                {b.categoria && (
                  <Badge tone="green" className="mt-1">{b.categoria}</Badge>
                )}
              </div>
              <span className="flex items-center gap-1.5 text-xs font-semibold text-warning whitespace-nowrap">
                <ClockAlert size={13} />
                {diasLabel(b.ultimoManejoMillis)}
              </span>
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
}
