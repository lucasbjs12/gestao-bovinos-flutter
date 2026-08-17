"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import {
  Beef,
  Sprout,
  Syringe,
  Plus,
  ArrowRight,
  Eye,
  EyeOff,
  ClockAlert,
  ArchiveX,
  Crown,
} from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { bovinosApi } from "@/lib/api/bovinos";
import { invernadasApi } from "@/lib/api/invernadas";
import { eventosApi } from "@/lib/api/eventos";
import { buscarTodasPaginas } from "@/lib/api/pagination";
import { planosApi, AssinaturaAtual } from "@/lib/api/planos";
import { PageHeader } from "@/components/ui/PageHeader";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";

interface Resumo {
  totalBovinos: number;
  totalInvernadas: number;
  eventosUltimos30Dias: number;
  vacas: number;
  novilhos: number;
  terneiros: number;
  outros: number;
  semManejo: number;
  baixados: number;
}

function saudacao() {
  const h = new Date().getHours();
  if (h < 12) return "Bom dia";
  if (h < 18) return "Boa tarde";
  return "Boa noite";
}

function grupoCategoria(categoria?: string | null): "vacas" | "novilhos" | "terneiros" | "outros" {
  const c = (categoria ?? "").toLowerCase();
  if (c === "vaca") return "vacas";
  if (c === "novilho" || c === "novilha") return "novilhos";
  if (c.startsWith("terneir")) return "terneiros";
  return "outros";
}

const OCULTAR_TOTAL_KEY = "ocultar_total_rebanho";

export default function InicioPage() {
  const { fazendaId, user, souDono } = useAuth();
  const [resumo, setResumo] = useState<Resumo | null>(null);
  const [ocultarTotal, setOcultarTotal] = useState(false);
  const [assinatura, setAssinatura] = useState<AssinaturaAtual | null>(null);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setOcultarTotal(localStorage.getItem(OCULTAR_TOTAL_KEY) === "1");
  }, []);

  function toggleOcultarTotal() {
    setOcultarTotal((v) => {
      const novo = !v;
      localStorage.setItem(OCULTAR_TOTAL_KEY, novo ? "1" : "0");
      return novo;
    });
  }

  useEffect(() => {
    if (!fazendaId) return;

    async function carregar() {
      const [todosBovinos, invernadasTotal, todosEventos] = await Promise.all([
        buscarTodasPaginas((page) => bovinosApi.listar(fazendaId!, { page, pageSize: 100 })),
        invernadasApi.listar(fazendaId!, { pageSize: 1 }).then((r) => r.paginacao.total),
        buscarTodasPaginas((page) => eventosApi.listar(fazendaId!, { page, pageSize: 100 })),
      ]);

      const bovinosAtivos = todosBovinos.filter((b) => b.status === "Ativo");
      const bovinosBaixados = todosBovinos.filter((b) => b.status !== "Ativo");

      const trintaDiasAtras = Date.now() - 30 * 24 * 60 * 60 * 1000;
      const eventosRecentes = todosEventos.filter((e) => {
        const millis = e.dataEvento ? new Date(e.dataEvento).getTime() : null;
        return millis && millis >= trintaDiasAtras;
      }).length;

      const ultimoManejoPorBovino = new Map<string, number>();
      todosEventos.forEach((e) => {
        const millis = e.dataEvento ? new Date(e.dataEvento).getTime() : null;
        if (!millis) return;
        e.bovinos.forEach(({ bovinoId }) => {
          const atual = ultimoManejoPorBovino.get(bovinoId) ?? 0;
          if (millis > atual) ultimoManejoPorBovino.set(bovinoId, millis);
        });
      });

      let vacas = 0,
        novilhos = 0,
        terneiros = 0,
        outros = 0,
        semManejo = 0;

      bovinosAtivos.forEach((b) => {
        switch (grupoCategoria(b.categoria)) {
          case "vacas":
            vacas++;
            break;
          case "novilhos":
            novilhos++;
            break;
          case "terneiros":
            terneiros++;
            break;
          default:
            outros++;
        }
        const ultimo = ultimoManejoPorBovino.get(b.id);
        if (!ultimo || ultimo < trintaDiasAtras) semManejo++;
      });

      setResumo({
        totalBovinos: bovinosAtivos.length,
        totalInvernadas: invernadasTotal,
        eventosUltimos30Dias: eventosRecentes,
        vacas,
        novilhos,
        terneiros,
        outros,
        semManejo,
        baixados: bovinosBaixados.length,
      });
    }

    carregar();
  }, [fazendaId]);

  useEffect(() => {
    if (!fazendaId || !souDono) return;
    planosApi.obterAssinatura(fazendaId).then(setAssinatura);
  }, [fazendaId, souDono]);

  const primeiroNome = user?.displayName?.split(" ")[0];

  return (
    <div>
      <PageHeader
        eyebrow={saudacao()}
        title={primeiroNome ? `Olá, ${primeiroNome}` : "Início"}
        subtitle="Resumo do rebanho em tempo real"
      />

      <Card className="p-5 mb-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xs font-bold uppercase tracking-wider text-muted">
            Total do rebanho
          </h2>
          <button
            onClick={toggleOcultarTotal}
            className="text-muted-2 hover:text-text"
            aria-label={ocultarTotal ? "Mostrar total" : "Ocultar total"}
          >
            {ocultarTotal ? <EyeOff size={16} /> : <Eye size={16} />}
          </button>
        </div>
        <div className="text-[34px] font-display font-semibold leading-none text-text mb-5">
          {ocultarTotal ? "•••" : resumo?.totalBovinos ?? "—"}
        </div>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          <SubContador label="Vacas" valor={resumo?.vacas} categoria="Vaca" />
          <SubContador label="Novilhos/as" valor={resumo?.novilhos} categoria="Novilho" />
          <SubContador label="Terneiros" valor={resumo?.terneiros} categoria="Terneiro" />
          <SubContador label="Outros" valor={resumo?.outros} categoria="" />
        </div>
      </Card>

      {souDono && assinatura && assinatura.limiteAnimaisAtual != null && (
        <Link
          href="/planos"
          className="block mb-6 rounded-2xl border border-border bg-surface px-5 py-4 hover:bg-cream transition-colors"
        >
          <div className="flex items-center justify-between gap-3 mb-2.5">
            <span className="flex items-center gap-2 text-sm font-semibold text-text">
              <Crown size={15} className="text-gold" />
              Plano{" "}
              {assinatura.status === "pendente" ? "Gratuito" : assinatura.plano?.nome ?? "Gratuito"}
            </span>
            <span className="text-xs font-semibold text-muted">
              {assinatura.contagemAnimais} / {assinatura.limiteAnimaisAtual} animais
            </span>
          </div>
          <div className="h-1.5 rounded-full bg-cream2 overflow-hidden">
            <div
              className={`h-full rounded-full ${
                assinatura.contagemAnimais >= assinatura.limiteAnimaisAtual ? "bg-danger" : "bg-g700"
              }`}
              style={{
                width: `${Math.min(100, (assinatura.contagemAnimais / assinatura.limiteAnimaisAtual) * 100)}%`,
              }}
            />
          </div>
        </Link>
      )}

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-6">
        <StatCard
          icon={<Beef size={20} />}
          label="Bovinos ativos"
          valor={resumo?.totalBovinos}
          tone="green"
          href="/bovinos"
        />
        <StatCard
          icon={<Sprout size={20} />}
          label="Invernadas"
          valor={resumo?.totalInvernadas}
          tone="blue"
          href="/invernadas"
        />
        <StatCard
          icon={<Syringe size={20} />}
          label="Eventos (30 dias)"
          valor={resumo?.eventosUltimos30Dias}
          tone="gold"
          href="/eventos"
        />
      </div>

      <Card className="p-5 mb-6">
        <h2 className="text-sm font-bold text-text mb-3.5">Histórico</h2>
        <Link
          href="/bovinos/baixados"
          className="flex items-center justify-between px-4 py-3 rounded-xl bg-cream hover:bg-cream2 transition-colors"
        >
          <span className="flex items-center gap-2.5 text-sm font-medium text-text">
            <ArchiveX size={16} className="text-muted-2" />
            Animais baixados
          </span>
          <span className="flex items-center gap-2 text-sm font-semibold text-muted">
            {resumo?.baixados ?? "—"}
            <ArrowRight size={14} />
          </span>
        </Link>
      </Card>

      {resumo && resumo.semManejo > 0 && (
        <Card className="p-5 mb-6">
          <h2 className="text-sm font-bold text-text mb-3.5">Atenção necessária</h2>
          <div className="flex flex-col gap-2">
            <Link
              href="/bovinos/sem-manejo"
              className="flex items-center justify-between px-4 py-3 rounded-xl bg-warning-bg hover:bg-warning-bg/70 transition-colors"
            >
              <span className="flex items-center gap-2.5 text-sm font-medium text-text">
                <ClockAlert size={16} className="text-warning" />
                Sem manejo sanitário (30 dias)
              </span>
              <span className="flex items-center gap-2 text-sm font-semibold text-warning">
                {resumo.semManejo}
                <ArrowRight size={14} />
              </span>
            </Link>
          </div>
        </Card>
      )}

      <Card className="p-5">
        <h2 className="text-sm font-bold text-text mb-3.5">Ações rápidas</h2>
        <div className="flex flex-wrap gap-2.5">
          <Button href="/bovinos/novo" variant="secondary" size="sm" icon={<Plus size={14} />}>
            Novo bovino
          </Button>
          <Button href="/bovinos/lote" variant="secondary" size="sm" icon={<Plus size={14} />}>
            Cadastro em lote
          </Button>
          <Button href="/invernadas/nova" variant="secondary" size="sm" icon={<Plus size={14} />}>
            Nova invernada
          </Button>
          <Button href="/eventos/novo" variant="secondary" size="sm" icon={<Plus size={14} />}>
            Novo evento
          </Button>
        </div>
      </Card>
    </div>
  );
}

function SubContador({
  label,
  valor,
  categoria,
}: {
  label: string;
  valor: number | undefined;
  categoria: string;
}) {
  return (
    <Link
      href={categoria ? `/bovinos?categoria=${encodeURIComponent(categoria)}` : "/bovinos"}
      className="flex flex-col items-center justify-center gap-1 py-3 rounded-xl bg-cream hover:bg-cream2 transition-colors"
    >
      <div className="text-lg font-display font-semibold text-text">{valor ?? "—"}</div>
      <div className="text-[11px] text-muted">{label}</div>
    </Link>
  );
}

function StatCard({
  icon,
  label,
  valor,
  tone,
  href,
}: {
  icon: React.ReactNode;
  label: string;
  valor: number | undefined;
  tone: "green" | "blue" | "gold";
  href: string;
}) {
  const tones = {
    green: "bg-g50 text-g800",
    blue: "bg-info-bg text-info",
    gold: "bg-gold-50 text-[#8a6516]",
  };
  return (
    <Card className="p-5 hover:shadow-md hover:-translate-y-0.5 transition-all">
      <Link href={href} className="flex items-start justify-between">
        <div className="flex items-start gap-3.5">
          <div className={`w-11 h-11 rounded-xl flex items-center justify-center shrink-0 ${tones[tone]}`}>
            {icon}
          </div>
          <div>
            <div className="text-[26px] font-display font-semibold leading-none text-text">
              {valor ?? <span className="skeleton inline-block w-8 h-6 align-middle" />}
            </div>
            <div className="text-xs text-muted mt-1.5">{label}</div>
          </div>
        </div>
        <ArrowRight size={15} className="text-muted-2 mt-1" />
      </Link>
    </Card>
  );
}
