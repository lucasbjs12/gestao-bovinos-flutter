"use client";

import { useCallback, useEffect, useState } from "react";
import { Star, Check } from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import {
  planosApi,
  Plano,
  AssinaturaAtual,
  PeriodicidadePlano,
  StatusPlano,
  valorReais,
  valorMensalEquivalente,
  formatarReais,
} from "@/lib/api/planos";
import { PageHeader } from "@/components/ui/PageHeader";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Badge } from "@/components/ui/Badge";

function formatarData(iso: string): string {
  const d = new Date(iso);
  return `${String(d.getDate()).padStart(2, "0")}/${String(d.getMonth() + 1).padStart(2, "0")}/${d.getFullYear()}`;
}

const STATUS_BADGE: Record<StatusPlano, { tone: "green" | "gold" | "red" | "gray"; texto: string }> = {
  ativo: { tone: "green", texto: "Ativo" },
  gratuito: { tone: "gray", texto: "Gratuito" },
  pendente: { tone: "gold", texto: "Pendente" },
  vencido: { tone: "red", texto: "Vencido" },
  cancelado: { tone: "red", texto: "Cancelado" },
};

export default function PlanosPage() {
  const { fazendaId } = useAuth();
  const [assinatura, setAssinatura] = useState<AssinaturaAtual | null>(null);
  const [planos, setPlanos] = useState<Plano[]>([]);
  const [periodicidade, setPeriodicidade] = useState<PeriodicidadePlano>("mensal");
  const [carregandoPlanoId, setCarregandoPlanoId] = useState<string | null>(null);
  const [cancelando, setCancelando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  const carregar = useCallback(async () => {
    if (!fazendaId) return;
    const [a, p] = await Promise.all([
      planosApi.obterAssinatura(fazendaId),
      planosApi.listar(),
    ]);
    setAssinatura(a);
    setPlanos(p);
  }, [fazendaId]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    carregar();
  }, [carregar]);

  async function assinar(plano: Plano) {
    if (!fazendaId) return;
    setErro(null);
    setCarregandoPlanoId(plano.id);
    try {
      const { checkoutUrl } = await planosApi.iniciarCheckout(fazendaId, plano.id);
      // Navegação de saída pro checkout do Mercado Pago (fora do domínio,
      // não é rota do Next -- router.push não serve pra URL externa).
      // eslint-disable-next-line react-hooks/immutability
      window.location.href = checkoutUrl;
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Erro ao iniciar assinatura.");
      setCarregandoPlanoId(null);
    }
  }

  async function cancelar() {
    if (!fazendaId) return;
    if (!window.confirm("Cancelar sua assinatura? Ela continua valendo até o fim do período já pago.")) {
      return;
    }
    setCancelando(true);
    try {
      await planosApi.cancelar(fazendaId);
      await carregar();
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Erro ao cancelar.");
    } finally {
      setCancelando(false);
    }
  }

  if (!assinatura) {
    return (
      <div className="max-w-3xl">
        <PageHeader title="Planos e Assinatura" />
        <div className="flex justify-center py-16">
          <span className="w-6 h-6 rounded-full border-2 border-border border-t-g700 spin" />
        </div>
      </div>
    );
  }

  const badge = STATUS_BADGE[assinatura.status];
  const planosDaPeriodicidade = planos.filter(
    (p) => p.valorCentavos === 0 || p.periodicidade === periodicidade
  );

  return (
    <div className="max-w-3xl">
      <PageHeader title="Planos e Assinatura" subtitle="Gerencie seu plano e o limite de animais do rebanho" />

      {erro && (
        <div className="mb-4 rounded-lg bg-danger-bg px-3.5 py-2.5 text-sm text-danger">{erro}</div>
      )}

      <Card className="p-6 mb-8">
        <div className="flex items-start justify-between gap-4 flex-wrap mb-4">
          <div>
            <div className="text-xs font-semibold text-muted uppercase tracking-wide mb-1">
              Seu plano atual
            </div>
            <div className="font-display text-xl font-semibold text-text">
              {assinatura.plano?.nome ?? "Gratuito"}
            </div>
          </div>
          <Badge tone={badge.tone}>{badge.texto}</Badge>
        </div>

        <div className="text-sm text-text mb-2">
          {assinatura.limiteAnimaisAtual == null
            ? `${assinatura.contagemAnimais} animais cadastrados · sem limite`
            : `${assinatura.contagemAnimais} de ${assinatura.limiteAnimaisAtual} animais cadastrados`}
        </div>
        {assinatura.limiteAnimaisAtual != null && (
          <div className="h-2 rounded-full bg-cream2 overflow-hidden">
            <div
              className={`h-full rounded-full ${
                assinatura.contagemAnimais >= assinatura.limiteAnimaisAtual ? "bg-danger" : "bg-g700"
              }`}
              style={{
                width: `${Math.min(100, (assinatura.contagemAnimais / assinatura.limiteAnimaisAtual) * 100)}%`,
              }}
            />
          </div>
        )}

        {assinatura.status === "cancelado" && assinatura.proximaCobranca && (
          <p className="text-xs text-muted mt-3">
            Cancelada -- continua valendo até {formatarData(assinatura.proximaCobranca)}.
          </p>
        )}
        {assinatura.status === "ativo" && (
          <div className="mt-4">
            <Button variant="secondary" size="sm" loading={cancelando} onClick={cancelar}>
              Gerenciar assinatura
            </Button>
          </div>
        )}
      </Card>

      <div className="flex items-center justify-between flex-wrap gap-3 mb-4">
        <h2 className="font-display text-base font-semibold text-text">Planos disponíveis</h2>
        <div className="inline-flex rounded-lg border border-border p-1 bg-surface">
          <button
            onClick={() => setPeriodicidade("mensal")}
            className={`px-3.5 py-1.5 rounded-md text-xs font-semibold transition-colors ${
              periodicidade === "mensal" ? "bg-g800 text-white" : "text-muted"
            }`}
          >
            Mensal
          </button>
          <button
            onClick={() => setPeriodicidade("anual")}
            className={`px-3.5 py-1.5 rounded-md text-xs font-semibold transition-colors ${
              periodicidade === "anual" ? "bg-g800 text-white" : "text-muted"
            }`}
          >
            Anual · economize
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {planosDaPeriodicidade.map((plano) => {
          const ehAtual =
            assinatura.plano?.id === plano.id || (plano.valorCentavos === 0 && !assinatura.plano);
          const anual = plano.periodicidade === "anual";
          return (
            <Card
              key={plano.id}
              className={`p-5 flex flex-col ${plano.destaque ? "border-gold border-2" : ""}`}
            >
              <div className="flex items-center gap-1.5 mb-1">
                <span className="font-semibold text-text">{plano.nome}</span>
                {plano.destaque && <Star size={14} className="text-gold" fill="currentColor" />}
              </div>
              <p className="text-xs text-muted mb-4">
                {plano.limiteAnimais == null ? "Animais ilimitados" : `Até ${plano.limiteAnimais} animais`}
              </p>

              {plano.valorCentavos === 0 ? (
                <div className="font-display text-2xl font-bold text-text mb-4">R$ 0</div>
              ) : (
                <div className="mb-4">
                  {anual && (
                    <div className="text-xs text-muted line-through">
                      R$ {formatarReais(valorReais(plano))}/mês
                    </div>
                  )}
                  <div className="font-display text-2xl font-bold text-text">
                    R$ {formatarReais(valorMensalEquivalente(plano))}/mês
                  </div>
                  {anual && (
                    <>
                      <p className="text-xs text-muted mt-0.5">
                        R$ {formatarReais(valorReais(plano))} cobrados anualmente
                      </p>
                      <p className="text-xs text-g700 font-semibold mt-0.5">
                        Economize R$ {formatarReais(valorReais(plano) / 5)} por ano
                      </p>
                    </>
                  )}
                </div>
              )}

              <div className="mt-auto">
                {ehAtual ? (
                  <div className="flex items-center gap-1.5 text-xs font-semibold text-muted justify-center py-2.5">
                    <Check size={14} /> Plano atual
                  </div>
                ) : plano.valorCentavos === 0 ? null : (
                  <Button
                    className="w-full"
                    variant={plano.destaque ? "gold" : "primary"}
                    loading={carregandoPlanoId === plano.id}
                    onClick={() => assinar(plano)}
                  >
                    Assinar
                  </Button>
                )}
              </div>
            </Card>
          );
        })}
      </div>

      <p className="text-xs text-muted mt-6">
        Os animais já cadastrados nunca são apagados ou bloqueados -- o limite do plano só afeta
        novos cadastros.
      </p>
    </div>
  );
}
