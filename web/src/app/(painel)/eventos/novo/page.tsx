"use client";

import { useEffect, useMemo, useState, FormEvent } from "react";
import { useRouter } from "next/navigation";
import { AlertCircle, Search, CheckSquare, Square } from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { eventosApi, TipoEventoSanitario } from "@/lib/api/eventos";
import { bovinosApi, CorDestaque } from "@/lib/api/bovinos";
import { invernadasApi } from "@/lib/api/invernadas";
import { buscarTodasPaginas } from "@/lib/api/pagination";
import { PageHeader } from "@/components/ui/PageHeader";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { FormField } from "@/components/ui/FormField";
import { CORES_DESTAQUE, CORES_DESTAQUE_LISTA, NOMES_DESTAQUE } from "@/lib/corDestaque";

const TIPOS: { value: TipoEventoSanitario; label: string }[] = [
  { value: "Vacinacao", label: "Vacinação" },
  { value: "Vermifugacao", label: "Vermifugação" },
  { value: "Medicacao", label: "Medicação" },
  { value: "Castracao", label: "Castração" },
  { value: "Banho", label: "Banho" },
  { value: "Outros", label: "Outros" },
];

interface BovinoOpcao {
  id: string;
  numeroBrinco: string;
  nomeAnimal?: string | null;
  invernadaId?: string | null;
}

interface InvernadaOpcao {
  id: string;
  descricao: string;
}

function StepDot({ active, done }: { active: boolean; done: boolean }) {
  return (
    <span
      className={`h-1.5 rounded-full transition-all ${
        active ? "w-8 bg-g700" : done ? "w-4 bg-g400" : "w-4 bg-border"
      }`}
    />
  );
}

export default function NovoEventoPage() {
  const { fazendaId } = useAuth();
  const router = useRouter();

  const [etapa, setEtapa] = useState<1 | 2>(1);

  const [tipo, setTipo] = useState<TipoEventoSanitario>(TIPOS[0].value);
  const [data, setData] = useState(() =>
    new Date().toISOString().slice(0, 10)
  );
  const [produto, setProduto] = useState("");
  const [dosagem, setDosagem] = useState("");
  const [responsavel, setResponsavel] = useState("");
  const [observacoes, setObservacoes] = useState("");

  const [destacar, setDestacar] = useState(false);
  const [corDestaque, setCorDestaque] = useState<CorDestaque | null>(null);
  const [rotuloDestaque, setRotuloDestaque] = useState("");

  const [bovinos, setBovinos] = useState<BovinoOpcao[]>([]);
  const [invernadas, setInvernadas] = useState<InvernadaOpcao[]>([]);
  const [filtroInvernada, setFiltroInvernada] = useState("");
  const [busca, setBusca] = useState("");
  const [selecionados, setSelecionados] = useState<Set<string>>(new Set());

  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  useEffect(() => {
    if (!fazendaId) return;
    buscarTodasPaginas((page) => bovinosApi.listar(fazendaId, { page, pageSize: 100 })).then(
      (todosBovinos) =>
        setBovinos(
          todosBovinos.map((b) => ({
            id: b.id,
            numeroBrinco: b.numeroBrinco,
            nomeAnimal: b.nomeAnimal,
            invernadaId: b.invernadaId,
          }))
        )
    );
    buscarTodasPaginas((page) => invernadasApi.listar(fazendaId, { page, pageSize: 100 })).then(
      (todasInvernadas) =>
        setInvernadas(todasInvernadas.map((i) => ({ id: i.id, descricao: i.descricao })))
    );

    // Vindo da seleção em massa da lista de Bovinos: pula direto pra etapa 2
    // já com os animais marcados.
    const preselecionados = sessionStorage.getItem("bovinosPreselecionados");
    if (preselecionados) {
      sessionStorage.removeItem("bovinosPreselecionados");
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setSelecionados(new Set(JSON.parse(preselecionados) as string[]));
      setEtapa(2);
    }
  }, [fazendaId]);

  const filtrados = useMemo(() => {
    return bovinos.filter((b) => {
      if (filtroInvernada && b.invernadaId !== filtroInvernada)
        return false;
      const alvo = `${b.numeroBrinco} ${b.nomeAnimal ?? ""}`.toLowerCase();
      return alvo.includes(busca.toLowerCase());
    });
  }, [bovinos, filtroInvernada, busca]);

  function toggle(id: string) {
    setSelecionados((prev) => {
      const novo = new Set(prev);
      if (novo.has(id)) novo.delete(id);
      else novo.add(id);
      return novo;
    });
  }

  const todosSelecionados =
    filtrados.length > 0 && filtrados.every((b) => selecionados.has(b.id));

  function selecionarTodos() {
    setSelecionados((prev) => {
      const novo = new Set(prev);
      filtrados.forEach((b) =>
        todosSelecionados ? novo.delete(b.id) : novo.add(b.id)
      );
      return novo;
    });
  }

  function avancar() {
    if (!tipo) {
      setErro("Selecione o tipo de evento.");
      return;
    }
    if (destacar && !corDestaque) {
      setErro("Escolha uma cor para o destaque.");
      return;
    }
    setErro(null);
    setEtapa(2);
  }

  async function salvar(e: FormEvent) {
    e.preventDefault();
    if (!fazendaId) return;
    if (selecionados.size === 0) {
      setErro("Selecione ao menos um animal.");
      return;
    }
    setErro(null);
    setSalvando(true);
    try {
      await eventosApi.criar(fazendaId, {
        tipo,
        dataEvento: data || null,
        produtoUtilizado: produto.trim() || null,
        dosagem: dosagem.trim() || null,
        responsavel: responsavel.trim() || null,
        observacoes: observacoes.trim() || null,
        invernadaId: filtroInvernada || null,
        bovinoIds: Array.from(selecionados),
      });

      if (destacar && corDestaque) {
        const rotulo = rotuloDestaque.trim() || NOMES_DESTAQUE[corDestaque];
        await Promise.all(
          Array.from(selecionados).map((id) =>
            bovinosApi.atualizar(fazendaId, id, {
              corDestaque,
              rotuloDestaque: rotulo,
            })
          )
        );
      }

      router.push("/eventos");
    } catch {
      setErro("Não foi possível salvar. Tente novamente.");
    } finally {
      setSalvando(false);
    }
  }

  return (
    <div className="max-w-2xl">
      <PageHeader
        title="Novo evento sanitário"
        subtitle={etapa === 1 ? "Dados do evento" : "Seleção de animais"}
      />

      <div className="flex items-center gap-2 mb-5 -mt-3">
        <StepDot active={etapa === 1} done={etapa > 1} />
        <StepDot active={etapa === 2} done={false} />
      </div>

      {erro && (
        <div className="flex items-start gap-2 bg-danger-bg rounded-lg px-3.5 py-2.5 text-sm text-danger mb-4">
          <AlertCircle size={16} className="shrink-0 mt-0.5" />
          {erro}
        </div>
      )}

      {etapa === 1 && (
        <Card className="p-6 flex flex-col gap-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <FormField label="Tipo *">
              <select
                value={tipo}
                onChange={(e) => setTipo(e.target.value as TipoEventoSanitario)}
                className="field"
              >
                {TIPOS.map((t) => (
                  <option key={t.value} value={t.value}>
                    {t.label}
                  </option>
                ))}
              </select>
            </FormField>
            <FormField label="Data">
              <input
                type="date"
                value={data}
                onChange={(e) => setData(e.target.value)}
                className="field"
              />
            </FormField>
            <FormField label="Produto utilizado">
              <input
                value={produto}
                onChange={(e) => setProduto(e.target.value)}
                className="field"
              />
            </FormField>
            <FormField label="Dosagem">
              <input
                value={dosagem}
                onChange={(e) => setDosagem(e.target.value)}
                className="field"
              />
            </FormField>
            <FormField label="Responsável">
              <input
                value={responsavel}
                onChange={(e) => setResponsavel(e.target.value)}
                className="field"
              />
            </FormField>
          </div>
          <FormField label="Observações">
            <textarea
              value={observacoes}
              onChange={(e) => setObservacoes(e.target.value)}
              rows={3}
              className="field resize-none"
            />
          </FormField>

          <div className="border-t border-border-soft pt-4">
            <label className="flex items-start gap-3 cursor-pointer">
              <input
                type="checkbox"
                checked={destacar}
                onChange={(e) => {
                  const v = e.target.checked;
                  setDestacar(v);
                  if (v && !rotuloDestaque.trim()) setRotuloDestaque(produto.trim());
                  if (!v) setCorDestaque(null);
                }}
                className="w-4 h-4 mt-0.5 accent-g700"
              />
              <span>
                <span className="text-sm font-semibold block">
                  Destacar os animais selecionados
                </span>
                <span className="text-xs text-muted">
                  Marca esses animais com uma cor na lista, até você remover.
                </span>
              </span>
            </label>

            {destacar && (
              <div className="mt-3 flex flex-col gap-3">
                <div className="flex gap-2">
                  {CORES_DESTAQUE_LISTA.map((cor) => (
                    <button
                      key={cor}
                      type="button"
                      onClick={() => setCorDestaque(cor)}
                      title={NOMES_DESTAQUE[cor]}
                      className="w-8 h-8 rounded-full flex items-center justify-center transition-transform hover:scale-105"
                      style={{
                        backgroundColor: CORES_DESTAQUE[cor],
                        border:
                          corDestaque === cor
                            ? "2.5px solid #1a1a1a"
                            : "1px solid rgba(0,0,0,0.15)",
                      }}
                    >
                      {corDestaque === cor && (
                        <span className="text-white text-xs">✓</span>
                      )}
                    </button>
                  ))}
                </div>
                <FormField label="Rótulo do destaque">
                  <input
                    value={rotuloDestaque}
                    onChange={(e) => setRotuloDestaque(e.target.value)}
                    placeholder="Ex: Vacina X - reforço"
                    className="field"
                  />
                </FormField>
              </div>
            )}
          </div>

          <div className="flex gap-3 mt-2">
            <Button type="button" onClick={avancar} className="flex-1">
              Avançar → selecionar animais
            </Button>
            <Button type="button" variant="secondary" onClick={() => router.back()}>
              Cancelar
            </Button>
          </div>
        </Card>
      )}

      {etapa === 2 && (
        <Card className="overflow-hidden">
          <form onSubmit={salvar}>
            <div className="p-5 border-b border-border-soft flex flex-wrap gap-3 items-center">
              <select
                value={filtroInvernada}
                onChange={(e) => setFiltroInvernada(e.target.value)}
                className="field max-w-[220px]"
              >
                <option value="">Todas as invernadas</option>
                {invernadas.map((inv) => (
                  <option key={inv.id} value={inv.id}>
                    {inv.descricao}
                  </option>
                ))}
              </select>
              <div className="relative flex-1 min-w-[180px]">
                <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-2" />
                <input
                  placeholder="Buscar por brinco ou nome…"
                  value={busca}
                  onChange={(e) => setBusca(e.target.value)}
                  className="field !pl-9"
                />
              </div>
              <button
                type="button"
                onClick={selecionarTodos}
                className="flex items-center gap-1.5 px-3.5 py-2 rounded-lg text-xs font-semibold border border-border hover:bg-cream whitespace-nowrap"
              >
                {todosSelecionados ? <CheckSquare size={14} /> : <Square size={14} />}
                Selecionar todos ({filtrados.length})
              </button>
            </div>

            <div className="max-h-96 overflow-y-auto divide-y divide-border-soft">
              {filtrados.length === 0 && (
                <p className="px-5 py-8 text-center text-muted text-sm">
                  Nenhum animal encontrado.
                </p>
              )}
              {filtrados.map((b) => (
                <label
                  key={b.id}
                  className="flex items-center gap-3 px-5 py-3 hover:bg-g50 cursor-pointer transition-colors"
                >
                  <input
                    type="checkbox"
                    checked={selecionados.has(b.id)}
                    onChange={() => toggle(b.id)}
                    className="w-4 h-4 accent-g700"
                  />
                  <span className="text-sm font-mono font-bold">{b.numeroBrinco}</span>
                  {b.nomeAnimal && (
                    <span className="text-sm text-muted">{b.nomeAnimal}</span>
                  )}
                </label>
              ))}
            </div>

            <div className="p-5 border-t border-border-soft flex gap-3">
              <Button type="submit" loading={salvando} className="flex-1">
                {salvando
                  ? "Salvando…"
                  : `Salvar evento (${selecionados.size} selecionado${
                      selecionados.size === 1 ? "" : "s"
                    })`}
              </Button>
              <Button type="button" variant="secondary" onClick={() => setEtapa(1)}>
                ← Voltar
              </Button>
            </div>
          </form>
        </Card>
      )}
    </div>
  );
}
