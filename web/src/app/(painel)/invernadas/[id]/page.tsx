"use client";

import { useEffect, useState, FormEvent } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { AlertCircle, Trash2, Beef, Gauge, History } from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { invernadasApi } from "@/lib/api/invernadas";
import { bovinosApi } from "@/lib/api/bovinos";
import { buscarTodasPaginas } from "@/lib/api/pagination";
import { PageHeader } from "@/components/ui/PageHeader";
import { Card, CardHeader } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { FormField } from "@/components/ui/FormField";
import { EmptyState, Spinner } from "@/components/ui/EmptyState";

interface Animal {
  id: string;
  numeroBrinco: string;
  nomeAnimal?: string;
  pesoAtualKg?: number | null;
}

interface Movimentacao {
  id: string;
  bovinoNome: string;
  deNome: string;
  paraNome: string;
  data: string;
  responsavel?: string;
}

export default function DetalheInvernadaPage() {
  const { id } = useParams<{ id: string }>();
  const { fazendaId, souDono } = useAuth();
  const router = useRouter();

  const [carregando, setCarregando] = useState(true);
  const [descricao, setDescricao] = useState("");
  const [hectares, setHectares] = useState("");
  const [observacoes, setObservacoes] = useState("");
  const [animais, setAnimais] = useState<Animal[]>([]);
  const [movimentacoes, setMovimentacoes] = useState<Movimentacao[]>([]);
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  useEffect(() => {
    if (!fazendaId || !id) return;

    async function carregar() {
      const inv = await invernadasApi.buscarPorId(fazendaId!, id);
      setDescricao(inv.descricao ?? "");
      setHectares(inv.hectares != null ? String(parseFloat(inv.hectares)) : "");
      setObservacoes(inv.observacoes ?? "");

      const bovinosDaInvernada = await buscarTodasPaginas((page) =>
        bovinosApi.listar(fazendaId!, { invernadaId: id, page, pageSize: 100 })
      );
      setAnimais(
        bovinosDaInvernada.map((b) => ({
          id: b.id,
          numeroBrinco: b.numeroBrinco,
          nomeAnimal: b.nomeAnimal ?? undefined,
          pesoAtualKg: b.pesoAtualKg != null ? parseFloat(b.pesoAtualKg) : null,
        }))
      );

      const movs = await invernadasApi.movimentacoes(fazendaId!, id);
      const nomeOuSemInvernada = (inv: { descricao: string } | null) =>
        inv ? inv.descricao : "Sem invernada";
      setMovimentacoes(
        movs
          .map((m) => ({
            id: m.id,
            bovinoNome: m.bovino.nomeAnimal || m.bovino.numeroBrinco,
            deNome: nomeOuSemInvernada(m.invernadaAnterior),
            paraNome: nomeOuSemInvernada(m.novaInvernada),
            data: m.data,
            responsavel: m.responsavel ?? undefined,
          }))
          .sort((a, b) => b.data.localeCompare(a.data))
      );

      setCarregando(false);
    }

    carregar();

    // O botão "voltar" do navegador pode restaurar esta página a partir do
    // bfcache (uma foto congelada de antes de editar um bovino), sem rodar
    // nenhum JS de novo. `pageshow` com persisted=true detecta essa volta e
    // força buscar os dados atuais no backend.
    function aoRestaurarDoCache(e: PageTransitionEvent) {
      if (e.persisted) carregar();
    }
    window.addEventListener("pageshow", aoRestaurarDoCache);
    return () => window.removeEventListener("pageshow", aoRestaurarDoCache);
  }, [fazendaId, id]);

  async function salvar(e: FormEvent) {
    e.preventDefault();
    if (!fazendaId) return;
    if (!descricao.trim()) return setErro("Informe uma descrição.");
    setErro(null);
    setSalvando(true);
    try {
      await invernadasApi.atualizar(fazendaId, id, {
        descricao: descricao.trim(),
        hectares: hectares ? Number(hectares) : null,
        observacoes: observacoes.trim() || null,
      });
      router.push("/invernadas");
    } catch {
      setErro("Não foi possível salvar. Tente novamente.");
    } finally {
      setSalvando(false);
    }
  }

  async function remover() {
    if (!fazendaId) return;
    if (
      !confirm(
        `Excluir a invernada "${descricao}"? Os animais dela ficam sem invernada.`
      )
    )
      return;
    await invernadasApi.excluir(fazendaId, id);
    router.push("/invernadas");
  }

  const pesoTotal = animais.reduce((soma, a) => soma + (a.pesoAtualKg ?? 0), 0);
  const hectaresNum = hectares ? Number(hectares) : null;
  const lotacaoKgHa = hectaresNum ? Math.round(pesoTotal / hectaresNum) : null;

  if (carregando) {
    return (
      <Card>
        <Spinner />
      </Card>
    );
  }

  return (
    <div className="max-w-lg">
      <PageHeader
        title={descricao}
        action={
          souDono && (
            <Button variant="danger" size="sm" icon={<Trash2 size={13} />} onClick={remover}>
              Excluir
            </Button>
          )
        }
      />

      {erro && (
        <div className="flex items-start gap-2 bg-danger-bg rounded-lg px-3.5 py-2.5 text-sm text-danger mb-4">
          <AlertCircle size={16} className="shrink-0 mt-0.5" />
          {erro}
        </div>
      )}

      <Card className="p-6 mb-5">
        <form onSubmit={salvar} className="flex flex-col gap-4">
          <FormField label="Descrição *">
            <input value={descricao} onChange={(e) => setDescricao(e.target.value)} className="field" />
          </FormField>
          <FormField label="Hectares">
            <input type="number" step="0.01" value={hectares} onChange={(e) => setHectares(e.target.value)} className="field" />
          </FormField>
          <FormField label="Observações">
            <textarea value={observacoes} onChange={(e) => setObservacoes(e.target.value)} rows={3} className="field resize-none" />
          </FormField>
          <div className="flex gap-3 mt-2">
            <Button type="submit" loading={salvando} className="flex-1">
              {salvando ? "Salvando…" : "Salvar alterações"}
            </Button>
            <Button type="button" variant="secondary" onClick={() => router.back()}>
              Voltar
            </Button>
          </div>
        </form>
      </Card>

      <Card className="overflow-hidden">
        <CardHeader
          title={`Animais nesta invernada (${animais.length})`}
          action={
            animais.length > 0 && (
              <div className="flex items-center gap-4 text-xs">
                <span className="text-muted">
                  Peso total: <strong className="text-text">{pesoTotal} kg</strong>
                </span>
                {lotacaoKgHa != null && (
                  <span className="flex items-center gap-1 text-info font-semibold">
                    <Gauge size={13} />
                    {lotacaoKgHa} kg/ha
                  </span>
                )}
              </div>
            )
          }
        />
        {animais.length === 0 ? (
          <EmptyState icon={<Beef size={20} />} title="Nenhum animal aqui" />
        ) : (
          <div className="divide-y divide-border-soft">
            {animais.map((a) => (
              <Link key={a.id} href={`/bovinos/${a.id}`} className="flex items-center justify-between gap-2 px-5 py-3 text-sm hover:bg-g50 transition-colors">
                <span>
                  <span className="font-mono font-bold">{a.numeroBrinco}</span>{" "}
                  {a.nomeAnimal && <span className="text-muted">{a.nomeAnimal}</span>}
                </span>
                <span className="text-muted tabular-nums">
                  {a.pesoAtualKg != null ? `${a.pesoAtualKg} kg` : "—"}
                </span>
              </Link>
            ))}
          </div>
        )}
      </Card>

      <Card className="overflow-hidden mt-5">
        <CardHeader title={`Histórico de movimentações (${movimentacoes.length})`} />
        {movimentacoes.length === 0 ? (
          <EmptyState icon={<History size={20} />} title="Nenhuma movimentação registrada" />
        ) : (
          <div className="divide-y divide-border-soft">
            {movimentacoes.map((m) => (
              <div key={m.id} className="px-5 py-3 text-sm">
                <div className="text-text">
                  <span className="font-semibold">{m.bovinoNome}</span>{" "}
                  <span className="text-muted">
                    {m.deNome} → {m.paraNome}
                  </span>
                </div>
                <div className="text-xs text-muted mt-0.5">
                  {m.data}
                  {m.responsavel ? ` · ${m.responsavel}` : ""}
                </div>
              </div>
            ))}
          </div>
        )}
      </Card>
    </div>
  );
}
