"use client";

import { useEffect, useState } from "react";
import {
  ScrollText,
  Beef,
  Sprout,
  Syringe,
  ArrowDownCircle,
  RotateCcw,
  Trash2,
  Activity,
} from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { atividadesApi, Atividade } from "@/lib/api/atividades";
import { PageHeader } from "@/components/ui/PageHeader";
import { Card } from "@/components/ui/Card";
import { EmptyState, Spinner } from "@/components/ui/EmptyState";

function iconePorAcao(acao: string) {
  if (acao.startsWith("bovino_baixado")) return { icon: ArrowDownCircle, tone: "text-warning bg-warning-bg" };
  if (acao.startsWith("bovino_reativado")) return { icon: RotateCcw, tone: "text-g700 bg-g50" };
  if (acao.startsWith("bovino_excluido")) return { icon: Trash2, tone: "text-danger bg-danger-bg" };
  if (acao.startsWith("bovino")) return { icon: Beef, tone: "text-g700 bg-g50" };
  if (acao.startsWith("invernada")) return { icon: Sprout, tone: "text-g700 bg-g50" };
  if (acao.startsWith("evento")) return { icon: Syringe, tone: "text-info bg-info-bg" };
  return { icon: Activity, tone: "text-muted bg-cream2" };
}

export default function DiarioPage() {
  const { fazendaId } = useAuth();
  const [atividades, setAtividades] = useState<Atividade[] | null>(null);

  useEffect(() => {
    if (!fazendaId) return;
    atividadesApi
      .listar(fazendaId, { pageSize: 100 })
      .then((r) => setAtividades(r.itens));
  }, [fazendaId]);

  return (
    <div className="max-w-2xl">
      <PageHeader
        title="Diário de atividades"
        subtitle="Registro imutável de tudo que foi feito na fazenda, por quem e quando"
      />

      <Card className="overflow-hidden">
        {atividades === null && <Spinner />}
        {atividades !== null && atividades.length === 0 && (
          <EmptyState
            icon={<ScrollText size={22} />}
            title="Nenhuma atividade registrada"
            description="Toda ação feita na fazenda aparece aqui automaticamente."
          />
        )}
        <div className="divide-y divide-border-soft">
          {atividades?.map((a) => {
            const { icon: Icon, tone } = iconePorAcao(a.acao);
            return (
              <div key={a.id} className="flex items-start gap-3 px-5 py-4">
                <div className={`w-8 h-8 rounded-full flex items-center justify-center shrink-0 ${tone}`}>
                  <Icon size={14} />
                </div>
                <div className="min-w-0">
                  <div className="text-sm text-text">{a.descricao}</div>
                  <div className="text-xs text-muted mt-0.5">
                    {a.autorNome || "Alguém"} ·{" "}
                    {new Date(a.criadoEm).toLocaleString("pt-BR")}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </Card>
    </div>
  );
}
