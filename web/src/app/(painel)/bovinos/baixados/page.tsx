"use client";

import { useCallback, useEffect, useState } from "react";
import { Search, ArchiveX, RotateCcw, Trash2, Info } from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { bovinosApi } from "@/lib/api/bovinos";
import { buscarTodasPaginas } from "@/lib/api/pagination";
import { PageHeader } from "@/components/ui/PageHeader";
import { Card } from "@/components/ui/Card";
import { EmptyState, Spinner } from "@/components/ui/EmptyState";

interface Bovino {
  id: string;
  numeroBrinco: string;
  nomeAnimal?: string | null;
  status: string;
  motivo?: string;
}

export default function AnimaisBaixadosPage() {
  const { fazendaId, souDono } = useAuth();
  const [lista, setLista] = useState<Bovino[] | null>(null);
  const [busca, setBusca] = useState("");

  const carregar = useCallback(async () => {
    if (!fazendaId) return;
    const todos = await buscarTodasPaginas((page) =>
      bovinosApi.listar(fazendaId, { page, pageSize: 100 })
    );
    const baixados = todos.filter((b) => b.status !== "Ativo");
    // O motivo mais recente só vem no GET por id (baixas[]) -- busca em
    // paralelo, uma chamada por animal baixado.
    const comMotivo = await Promise.all(
      baixados.map(async (b) => {
        try {
          const completo = await bovinosApi.buscarPorId(fazendaId, b.id);
          const ultimaBaixa = completo.baixas?.[0];
          return { id: b.id, numeroBrinco: b.numeroBrinco, nomeAnimal: b.nomeAnimal, status: b.status, motivo: ultimaBaixa?.motivo };
        } catch {
          return { id: b.id, numeroBrinco: b.numeroBrinco, nomeAnimal: b.nomeAnimal, status: b.status };
        }
      })
    );
    setLista(comMotivo);
  }, [fazendaId]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    carregar();
  }, [carregar]);

  async function reativar(id: string) {
    if (!fazendaId) return;
    await bovinosApi.reativar(fazendaId, id);
    carregar();
  }

  async function excluirPermanente(id: string, nome: string) {
    if (!fazendaId) return;
    if (!confirm(`Excluir ${nome} permanentemente? Essa ação não pode ser desfeita.`))
      return;
    await bovinosApi.excluir(fazendaId, id);
    carregar();
  }

  const filtrados = (lista ?? []).filter((b) => {
    const alvo = `${b.numeroBrinco} ${b.nomeAnimal ?? ""}`.toLowerCase();
    return alvo.includes(busca.toLowerCase());
  });

  return (
    <div>
      <PageHeader
        title="Animais baixados"
        action={
          <div className="relative">
            <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-2" />
            <input
              placeholder="Buscar por brinco ou nome…"
              value={busca}
              onChange={(e) => setBusca(e.target.value)}
              className="field !pl-9 min-w-[220px]"
            />
          </div>
        }
      />

      {!souDono && (
        <div className="flex items-center gap-2 text-xs text-muted mb-4 bg-info-bg text-info px-3.5 py-2.5 rounded-lg">
          <Info size={14} className="shrink-0" />
          Somente o dono da fazenda pode reativar ou excluir animais.
        </div>
      )}

      <Card className="overflow-hidden">
        {lista === null && <Spinner />}
        {lista !== null && filtrados.length === 0 && (
          <EmptyState
            icon={<ArchiveX size={22} />}
            title="Nenhum animal baixado"
            description="Animais vendidos, abatidos ou perdidos aparecem aqui."
          />
        )}
        <div className="divide-y divide-border-soft">
          {filtrados.map((b) => (
            <div
              key={b.id}
              className="flex items-center justify-between gap-3 px-5 py-3.5"
            >
              <div>
                <div className="text-sm font-semibold text-text">
                  <span className="font-mono">{b.numeroBrinco}</span>
                  {b.nomeAnimal ? ` · ${b.nomeAnimal}` : ""}
                </div>
                <div className="text-xs text-muted">{b.motivo || b.status}</div>
              </div>
              {souDono && (
                <div className="flex gap-1 shrink-0">
                  <button
                    onClick={() => reativar(b.id)}
                    className="p-1.5 rounded-md text-muted-2 hover:text-g700 hover:bg-g50 transition-colors"
                    aria-label="Reativar"
                    title="Reativar"
                  >
                    <RotateCcw size={14} />
                  </button>
                  <button
                    onClick={() => excluirPermanente(b.id, b.nomeAnimal || b.numeroBrinco)}
                    className="p-1.5 rounded-md text-muted-2 hover:text-danger hover:bg-danger-bg transition-colors"
                    aria-label="Excluir"
                    title="Excluir permanentemente"
                  >
                    <Trash2 size={14} />
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
}
