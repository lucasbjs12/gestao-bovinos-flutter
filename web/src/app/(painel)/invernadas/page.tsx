"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Sprout, Plus, Trash2, Beef, Gauge } from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { invernadasApi } from "@/lib/api/invernadas";
import { bovinosApi } from "@/lib/api/bovinos";
import { buscarTodasPaginas } from "@/lib/api/pagination";
import { PageHeader } from "@/components/ui/PageHeader";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { EmptyState, Spinner } from "@/components/ui/EmptyState";

interface Invernada {
  id: string;
  descricao: string;
  hectares?: number;
  quantidadeBovinos?: number;
  categoriasBovinos?: string;
  observacoes?: string;
  pesoTotalKg?: number;
  lotacaoKgHa?: number | null;
}

export default function InvernadasPage() {
  const { fazendaId, souDono } = useAuth();
  const [invernadas, setInvernadas] = useState<Invernada[] | null>(null);

  async function carregar() {
    if (!fazendaId) return;
    const [todasInvernadas, todosBovinos] = await Promise.all([
      buscarTodasPaginas((page) => invernadasApi.listar(fazendaId, { page, pageSize: 100 })),
      buscarTodasPaginas((page) => bovinosApi.listar(fazendaId, { page, pageSize: 100 })),
    ]);
    const contagem = new Map<string, number>();
    const categorias = new Map<string, Set<string>>();
    const pesoTotal = new Map<string, number>();
    todosBovinos.forEach((b) => {
      const invId = b.invernadaId;
      if (!invId || b.status !== "Ativo") return;
      contagem.set(invId, (contagem.get(invId) ?? 0) + 1);
      if (b.categoria) {
        const set = categorias.get(invId) ?? new Set<string>();
        set.add(b.categoria);
        categorias.set(invId, set);
      }
      const peso = b.pesoAtualKg != null ? parseFloat(b.pesoAtualKg) : NaN;
      if (!Number.isNaN(peso)) {
        pesoTotal.set(invId, (pesoTotal.get(invId) ?? 0) + peso);
      }
    });
    setInvernadas(
      todasInvernadas.map((inv) => {
        const hectares = inv.hectares != null ? parseFloat(inv.hectares) : undefined;
        const peso = pesoTotal.get(inv.id) ?? 0;
        return {
          id: inv.id,
          descricao: inv.descricao,
          hectares,
          observacoes: inv.observacoes ?? undefined,
          quantidadeBovinos: contagem.get(inv.id) ?? 0,
          categoriasBovinos: Array.from(categorias.get(inv.id) ?? []).join(", "),
          pesoTotalKg: peso,
          lotacaoKgHa: hectares ? Math.round(peso / hectares) : null,
        };
      })
    );
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

  async function remover(id: string, descricao: string) {
    if (!fazendaId) return;
    if (
      !confirm(
        `Excluir a invernada "${descricao}"? Os animais dela ficam sem invernada.`
      )
    )
      return;
    await invernadasApi.excluir(fazendaId, id);
    carregar();
  }

  return (
    <div>
      <PageHeader
        title="Invernadas"
        subtitle={invernadas ? `${invernadas.length} áreas cadastradas` : undefined}
        action={
          <Button href="/invernadas/nova" icon={<Plus size={15} />}>
            Nova invernada
          </Button>
        }
      />

      {invernadas === null && (
        <Card>
          <Spinner />
        </Card>
      )}

      {invernadas !== null && invernadas.length === 0 && (
        <Card>
          <EmptyState
            icon={<Sprout size={22} />}
            title="Nenhuma invernada cadastrada"
            description="Crie a primeira área de pasto do rebanho."
            action={
              <Button href="/invernadas/nova" size="sm" icon={<Plus size={14} />}>
                Nova invernada
              </Button>
            }
          />
        </Card>
      )}

      <div className="flex flex-col gap-3">
        {invernadas?.map((inv) => (
          <Card
            key={inv.id}
            className="hover:shadow-md hover:border-g200 transition-all relative group"
          >
            <Link href={`/invernadas/${inv.id}`} className="flex items-center gap-5 px-5 py-4">
              <div className="w-11 h-11 rounded-xl bg-g50 flex items-center justify-center text-g800 shrink-0">
                <Sprout size={20} />
              </div>

              <div className="min-w-0 sm:min-w-[160px]">
                <div className="text-[15px] font-bold text-text truncate">
                  {inv.descricao}
                </div>
                <div className="text-xs text-muted">
                  {inv.hectares != null ? `${inv.hectares} ha` : "hectares não informado"}
                </div>
              </div>

              <div className="w-px self-stretch bg-border-soft hidden sm:block" />

              <div className="flex items-center gap-2 shrink-0">
                <Beef size={15} className="text-g700" />
                <span className="text-base font-display font-semibold leading-none">
                  {inv.quantidadeBovinos ?? 0}
                </span>
                <span className="text-[11px] text-muted">animais</span>
              </div>

              <div className="w-px self-stretch bg-border-soft hidden md:block" />

              <div className="hidden md:flex items-center gap-2 shrink-0" title="Taxa de lotação (peso total ÷ hectares)">
                <Gauge size={15} className="text-info" />
                <span className="text-base font-display font-semibold leading-none">
                  {inv.lotacaoKgHa != null ? inv.lotacaoKgHa : "—"}
                </span>
                <span className="text-[11px] text-muted">kg/ha</span>
              </div>

              {inv.categoriasBovinos && (
                <>
                  <div className="w-px self-stretch bg-border-soft hidden sm:block" />
                  <div className="flex-1 min-w-0 hidden sm:block">
                    <div className="text-xs font-semibold text-text truncate">
                      {inv.categoriasBovinos}
                    </div>
                    <div className="text-[10.5px] text-muted">categorias</div>
                  </div>
                </>
              )}

              <div className="flex-1" />
            </Link>
            {souDono && (
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  e.preventDefault();
                  remover(inv.id, inv.descricao);
                }}
                className="absolute top-1/2 -translate-y-1/2 right-4 p-1.5 rounded-md text-muted-2 opacity-100 sm:opacity-0 sm:group-hover:opacity-100 hover:text-danger hover:bg-danger-bg transition-all"
                aria-label="Excluir"
              >
                <Trash2 size={14} />
              </button>
            )}
          </Card>
        ))}
      </div>
    </div>
  );
}
