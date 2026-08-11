"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { HelpCircle } from "lucide-react";
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
}

export default function TerneirosIndefinidosPage() {
  const { fazendaId } = useAuth();
  const [lista, setLista] = useState<Bovino[] | null>(null);

  useEffect(() => {
    if (!fazendaId) return;
    async function carregar() {
      const todos = await buscarTodasPaginas((page) =>
        bovinosApi.listar(fazendaId!, { page, pageSize: 100 })
      );
      setLista(
        todos
          .filter(
            (b) =>
              b.status === "Ativo" &&
              (b.categoria === "Terneiro" || b.categoria === "Terneira") &&
              !b.idMae
          )
          .map((b) => ({ id: b.id, numeroBrinco: b.numeroBrinco, nomeAnimal: b.nomeAnimal }))
      );
    }
    carregar();
  }, [fazendaId]);

  return (
    <div>
      <PageHeader
        title="Terneiros indefinidos"
        subtitle="Terneiros ativos sem a vaca mãe vinculada"
      />

      <Card className="overflow-hidden">
        {lista === null && <Spinner />}
        {lista !== null && lista.length === 0 && (
          <EmptyState
            icon={<HelpCircle size={22} />}
            title="Nenhum terneiro pendente"
            description="Todos os terneiros já têm a mãe vinculada."
          />
        )}
        <div className="divide-y divide-border-soft">
          {lista?.map((b) => (
            <Link
              key={b.id}
              href={`/bovinos/${b.id}`}
              className="block px-5 py-3.5 text-sm font-semibold hover:bg-g50 transition-colors"
            >
              <span className="font-mono">{b.numeroBrinco}</span>
              {b.nomeAnimal ? ` · ${b.nomeAnimal}` : ""}
            </Link>
          ))}
        </div>
      </Card>
    </div>
  );
}
