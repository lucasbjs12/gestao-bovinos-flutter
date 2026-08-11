"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  Search,
  Plus,
  Beef,
  ClockAlert,
  HelpCircle,
  ArchiveX,
  Trash2,
  ArrowUpDown,
  CheckSquare,
  Square,
  X,
  Syringe,
  Sprout,
  ArrowDownCircle,
} from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { bovinosApi, MotivoBaixa } from "@/lib/api/bovinos";
import { invernadasApi } from "@/lib/api/invernadas";
import { movimentacoesApi } from "@/lib/api/movimentacoes";
import { buscarTodasPaginas } from "@/lib/api/pagination";
import { PageHeader } from "@/components/ui/PageHeader";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Badge } from "@/components/ui/Badge";
import { EmptyState, Spinner } from "@/components/ui/EmptyState";

interface Bovino {
  id: string;
  numeroBrinco: string;
  nomeAnimal?: string | null;
  categoria?: string | null;
  pesoAtualKg?: string | null;
  invernadaId?: string | null;
  status: string;
}

const REPORTS = [
  { href: "/bovinos/sem-manejo", label: "Sem manejo", icon: ClockAlert },
  { href: "/bovinos/terneiros-indefinidos", label: "Terneiros indefinidos", icon: HelpCircle },
  { href: "/bovinos/baixados", label: "Animais baixados", icon: ArchiveX },
];

const CATEGORIAS = [
  "Vaca",
  "Novilha",
  "Novilho",
  "Terneiro",
  "Terneira",
  "Touro",
  "Boi",
];

const MOTIVOS = ["Venda", "Morte", "Furto", "Outros"] as const;
const PAGE_SIZE = 30;

type Ordem = "brinco" | "nome" | "categoria" | "invernada" | "peso";

const ORDENS: { valor: Ordem; label: string }[] = [
  { valor: "brinco", label: "Brinco (crescente)" },
  { valor: "nome", label: "Nome A→Z" },
  { valor: "categoria", label: "Categoria" },
  { valor: "invernada", label: "Invernada" },
  { valor: "peso", label: "Peso (maior primeiro)" },
];

export default function BovinosPage() {
  const { fazendaId, souDono } = useAuth();
  const router = useRouter();
  const [bovinos, setBovinos] = useState<Bovino[] | null>(null);
  const [invernadas, setInvernadas] = useState<Map<string, string>>(new Map());
  const [busca, setBusca] = useState("");
  const [categoriaFiltro, setCategoriaFiltro] = useState("");
  const [ordem, setOrdem] = useState<Ordem>("brinco");
  const [menuOrdemAberto, setMenuOrdemAberto] = useState(false);

  const [modoSelecao, setModoSelecao] = useState(false);
  const [selecionados, setSelecionados] = useState<Set<string>>(new Set());
  const [modalMover, setModalMover] = useState(false);
  const [invernadaDestino, setInvernadaDestino] = useState("");
  const [modalBaixa, setModalBaixa] = useState(false);
  const [motivoBaixa, setMotivoBaixa] = useState<MotivoBaixa>(MOTIVOS[0]);
  const [processando, setProcessando] = useState(false);
  const [visivel, setVisivel] = useState(PAGE_SIZE);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setVisivel(PAGE_SIZE);
  }, [busca, categoriaFiltro, ordem]);

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const categoria = params.get("categoria");
    // eslint-disable-next-line react-hooks/set-state-in-effect
    if (categoria) setCategoriaFiltro(categoria);
  }, []);

  async function carregar() {
    if (!fazendaId) return;
    const [todosBovinos, todasInvernadas] = await Promise.all([
      buscarTodasPaginas((page) => bovinosApi.listar(fazendaId, { page, pageSize: 100 })),
      buscarTodasPaginas((page) => invernadasApi.listar(fazendaId, { page, pageSize: 100 })),
    ]);
    setInvernadas(new Map(todasInvernadas.map((i) => [i.id, i.descricao])));
    setBovinos(todosBovinos.filter((b) => b.status === "Ativo"));
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

  async function remover(id: string, brinco: string) {
    if (!fazendaId) return;
    if (!confirm(`Excluir o bovino ${brinco}? Essa ação não pode ser desfeita.`))
      return;
    await bovinosApi.excluir(fazendaId, id);
    carregar();
  }

  const filtrados = useMemo(() => {
    let lista = (bovinos ?? []).filter((b) => {
      const alvo = `${b.numeroBrinco} ${b.nomeAnimal ?? ""}`.toLowerCase();
      return alvo.includes(busca.toLowerCase());
    });
    if (categoriaFiltro) {
      lista = lista.filter(
        (b) => (b.categoria ?? "").toLowerCase() === categoriaFiltro.toLowerCase()
      );
    }
    const descricao = (b: Bovino) =>
      (b.invernadaId && invernadas.get(b.invernadaId)) || "";
    lista = [...lista].sort((a, b) => {
      switch (ordem) {
        case "nome":
          return (a.nomeAnimal || a.numeroBrinco).localeCompare(
            b.nomeAnimal || b.numeroBrinco
          );
        case "categoria":
          return (a.categoria ?? "").localeCompare(b.categoria ?? "");
        case "invernada":
          return descricao(a).localeCompare(descricao(b));
        case "peso":
          return (parseFloat(b.pesoAtualKg ?? "") || -1) - (parseFloat(a.pesoAtualKg ?? "") || -1);
        case "brinco":
        default: {
          const na = Number(a.numeroBrinco);
          const nb = Number(b.numeroBrinco);
          if (!Number.isNaN(na) && !Number.isNaN(nb)) return na - nb;
          return a.numeroBrinco.localeCompare(b.numeroBrinco);
        }
      }
    });
    return lista;
  }, [bovinos, busca, categoriaFiltro, ordem, invernadas]);

  function sairDoModoSelecao() {
    setModoSelecao(false);
    setSelecionados(new Set());
  }

  function toggleSelecao(id: string) {
    setSelecionados((prev) => {
      const novo = new Set(prev);
      if (novo.has(id)) novo.delete(id);
      else novo.add(id);
      if (novo.size === 0) setModoSelecao(false);
      return novo;
    });
  }

  const todosSelecionados =
    filtrados.length > 0 && filtrados.every((b) => selecionados.has(b.id));

  function selecionarTodos() {
    if (todosSelecionados) {
      sairDoModoSelecao();
      return;
    }
    setModoSelecao(true);
    setSelecionados(new Set(filtrados.map((b) => b.id)));
  }

  function irParaCriarEvento() {
    sessionStorage.setItem(
      "bovinosPreselecionados",
      JSON.stringify(Array.from(selecionados))
    );
    router.push("/eventos/novo");
  }

  async function confirmarMover() {
    if (!fazendaId) return;
    setProcessando(true);
    const hoje = new Date().toISOString().slice(0, 10);
    try {
      if (invernadaDestino) {
        await Promise.all(
          Array.from(selecionados).map((bovinoId) =>
            movimentacoesApi.criar(fazendaId, {
              bovinoId,
              novaInvernadaId: invernadaDestino,
              data: hoje,
            })
          )
        );
      } else {
        // "Sem invernada" não tem endpoint de movimentação dedicado (exige
        // destino) -- atualiza o bovino direto, sem gerar linha de histórico.
        await Promise.all(
          Array.from(selecionados).map((bovinoId) =>
            bovinosApi.atualizar(fazendaId, bovinoId, { invernadaId: null })
          )
        );
      }
      setModalMover(false);
      sairDoModoSelecao();
      carregar();
    } finally {
      setProcessando(false);
    }
  }

  async function confirmarBaixaLote() {
    if (!fazendaId || !bovinos) return;
    const alvo = bovinos.filter((b) => selecionados.has(b.id));
    if (
      !confirm(
        `Dar baixa em ${alvo.length} animal(is) por "${motivoBaixa}"? Essa ação não pode ser desfeita.`
      )
    )
      return;
    setProcessando(true);
    const hoje = new Date().toISOString().slice(0, 10);
    try {
      await Promise.all(
        alvo.map((b) =>
          bovinosApi.darBaixa(fazendaId, b.id, { motivo: motivoBaixa, dataBaixa: hoje })
        )
      );
      setModalBaixa(false);
      sairDoModoSelecao();
      carregar();
    } finally {
      setProcessando(false);
    }
  }

  return (
    <div className="pb-20">
      <PageHeader
        title="Bovinos"
        subtitle={bovinos ? `${bovinos.length} animais ativos no rebanho` : undefined}
        action={
          modoSelecao ? (
            <Button variant="secondary" icon={<X size={15} />} onClick={sairDoModoSelecao}>
              Cancelar seleção
            </Button>
          ) : (
            <>
              <div className="relative">
                <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-2" />
                <input
                  placeholder="Buscar por brinco ou nome…"
                  value={busca}
                  onChange={(e) => setBusca(e.target.value)}
                  className="field !pl-9 min-w-[220px]"
                />
              </div>
              <div className="relative">
                <button
                  onClick={() => setMenuOrdemAberto((v) => !v)}
                  onBlur={() => setTimeout(() => setMenuOrdemAberto(false), 150)}
                  className="flex items-center gap-1.5 px-3.5 py-2 rounded-[10px] text-sm font-semibold border-[1.5px] border-border bg-surface text-text hover:bg-cream"
                >
                  <ArrowUpDown size={14} />
                  Ordenar
                </button>
                {menuOrdemAberto && (
                  <div className="absolute right-0 mt-1.5 w-56 bg-surface border border-border rounded-xl shadow-md py-1.5 z-20">
                    {ORDENS.map((o) => (
                      <button
                        key={o.valor}
                        onMouseDown={() => setOrdem(o.valor)}
                        className={`w-full text-left px-3.5 py-2 text-sm hover:bg-cream ${
                          ordem === o.valor ? "text-g800 font-semibold" : "text-text"
                        }`}
                      >
                        {o.label}
                      </button>
                    ))}
                  </div>
                )}
              </div>
              <Button
                variant="secondary"
                icon={<CheckSquare size={15} />}
                onClick={() => setModoSelecao(true)}
              >
                Selecionar
              </Button>
              <Button href="/bovinos/novo" icon={<Plus size={15} />}>
                Novo bovino
              </Button>
            </>
          )
        }
      />

      {!modoSelecao && (
        <>
          <div className="flex gap-2 mb-4 flex-wrap">
            {REPORTS.map((r) => {
              const Icon = r.icon;
              return (
                <Link
                  key={r.href}
                  href={r.href}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full border border-border bg-surface text-xs font-semibold text-muted hover:text-g800 hover:border-g600 transition-colors"
                >
                  <Icon size={13} />
                  {r.label}
                </Link>
              );
            })}
          </div>

          <div className="flex gap-2 mb-5 flex-wrap">
            <button
              onClick={() => setCategoriaFiltro("")}
              className={`px-3 py-1.5 rounded-full text-xs font-semibold border transition-colors ${
                categoriaFiltro === ""
                  ? "bg-g800 text-white border-g800"
                  : "border-border text-muted hover:bg-cream bg-surface"
              }`}
            >
              Todos
            </button>
            {CATEGORIAS.map((c) => (
              <button
                key={c}
                onClick={() => setCategoriaFiltro(c === categoriaFiltro ? "" : c)}
                className={`px-3 py-1.5 rounded-full text-xs font-semibold border transition-colors ${
                  categoriaFiltro === c
                    ? "bg-g800 text-white border-g800"
                    : "border-border text-muted hover:bg-cream bg-surface"
                }`}
              >
                {c}
              </button>
            ))}
          </div>
        </>
      )}

      {modoSelecao && (
        <div className="flex items-center gap-3 mb-5">
          <button
            onClick={selecionarTodos}
            className="flex items-center gap-1.5 px-3.5 py-2 rounded-lg text-xs font-semibold border border-border hover:bg-cream bg-surface"
          >
            {todosSelecionados ? <CheckSquare size={14} /> : <Square size={14} />}
            {todosSelecionados ? "Desmarcar todos" : `Selecionar todos (${filtrados.length})`}
          </button>
          <span className="text-sm text-muted">
            {selecionados.size} selecionado{selecionados.size === 1 ? "" : "s"}
          </span>
        </div>
      )}

      <Card className="overflow-hidden">
        {bovinos === null && <Spinner />}

        {bovinos !== null && filtrados.length === 0 && (
          <EmptyState
            icon={<Beef size={22} />}
            title={bovinos.length === 0 ? "Nenhum bovino cadastrado" : "Nada encontrado"}
            description={
              bovinos.length === 0
                ? "Cadastre o primeiro animal do rebanho para começar."
                : "Tente buscar por outro brinco/nome ou limpar o filtro de categoria."
            }
            action={
              bovinos.length === 0 ? (
                <Button href="/bovinos/novo" size="sm" icon={<Plus size={14} />}>
                  Novo bovino
                </Button>
              ) : undefined
            }
          />
        )}

        {bovinos !== null && filtrados.length > 0 && (
          <div className="overflow-x-auto">
            <table className="w-full text-sm border-collapse">
              <thead>
                <tr className="bg-cream text-[10.5px] uppercase tracking-wider text-muted">
                  {modoSelecao && <th className="w-10 border-b border-border-soft" />}
                  <th className="text-left px-5 py-3 font-bold border-b border-border-soft">Brinco</th>
                  <th className="text-left px-5 py-3 font-bold border-b border-border-soft">Nome</th>
                  <th className="text-left px-5 py-3 font-bold border-b border-border-soft">Categoria</th>
                  <th className="text-left px-5 py-3 font-bold border-b border-border-soft">Peso</th>
                  <th className="text-left px-5 py-3 font-bold border-b border-border-soft">Invernada</th>
                  {souDono && !modoSelecao && <th className="border-b border-border-soft" />}
                </tr>
              </thead>
              <tbody>
                {filtrados.slice(0, visivel).map((b) => (
                  <tr
                    key={b.id}
                    onClick={() =>
                      modoSelecao ? toggleSelecao(b.id) : router.push(`/bovinos/${b.id}`)
                    }
                    className={`border-b border-border-soft last:border-none cursor-pointer transition-colors ${
                      selecionados.has(b.id) ? "bg-g50" : "hover:bg-g50"
                    }`}
                  >
                    {modoSelecao && (
                      <td className="pl-5 py-3.5">
                        <input
                          type="checkbox"
                          checked={selecionados.has(b.id)}
                          onChange={() => toggleSelecao(b.id)}
                          onClick={(e) => e.stopPropagation()}
                          className="w-4 h-4 accent-g700"
                        />
                      </td>
                    )}
                    <td className="px-5 py-3.5">
                      <span className="font-mono font-bold text-text tabular-nums">
                        {b.numeroBrinco}
                      </span>
                    </td>
                    <td className="px-5 py-3.5 text-text">{b.nomeAnimal || "—"}</td>
                    <td className="px-5 py-3.5">
                      {b.categoria ? (
                        <Badge tone="green">{b.categoria}</Badge>
                      ) : (
                        <span className="text-muted-2">—</span>
                      )}
                    </td>
                    <td className="px-5 py-3.5 text-text tabular-nums">
                      {b.pesoAtualKg ? `${b.pesoAtualKg} kg` : "—"}
                    </td>
                    <td className="px-5 py-3.5 text-muted">
                      {(b.invernadaId && invernadas.get(b.invernadaId)) || "—"}
                    </td>
                    {souDono && !modoSelecao && (
                      <td className="px-5 py-3.5 text-right">
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            remover(b.id, b.numeroBrinco);
                          }}
                          className="p-1.5 rounded-md text-muted-2 hover:text-danger hover:bg-danger-bg transition-colors"
                          aria-label="Excluir"
                        >
                          <Trash2 size={14} />
                        </button>
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      {filtrados.length > visivel && (
        <div className="flex justify-center mt-4">
          <Button
            variant="secondary"
            size="sm"
            onClick={() => setVisivel((v) => v + PAGE_SIZE)}
          >
            Carregar mais ({filtrados.length - visivel} restantes)
          </Button>
        </div>
      )}

      {modoSelecao && selecionados.size > 0 && (
        <div className="fixed bottom-16 lg:bottom-0 left-0 lg:left-64 right-0 bg-surface border-t border-border px-4 lg:px-8 py-3 lg:py-4 flex items-center gap-2 lg:gap-3 flex-wrap shadow-lg z-30">
          <span className="text-sm font-semibold text-text mr-2">
            {selecionados.size} selecionado{selecionados.size === 1 ? "" : "s"}
          </span>
          <Button size="sm" icon={<Syringe size={14} />} onClick={irParaCriarEvento}>
            Criar evento
          </Button>
          <Button
            size="sm"
            variant="secondary"
            icon={<Sprout size={14} />}
            onClick={() => setModalMover(true)}
          >
            Mover
          </Button>
          {souDono && (
            <Button
              size="sm"
              variant="danger"
              icon={<ArrowDownCircle size={14} />}
              onClick={() => setModalBaixa(true)}
            >
              Baixa
            </Button>
          )}
        </div>
      )}

      {modalMover && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-40 p-4">
          <Card className="w-full max-w-sm p-6">
            <h2 className="font-display text-lg font-semibold text-text mb-4">
              Mover {selecionados.size} animal(is)
            </h2>
            <label className="flex flex-col gap-1.5 mb-5">
              <span className="text-xs font-semibold text-text">Invernada de destino</span>
              <select
                value={invernadaDestino}
                onChange={(e) => setInvernadaDestino(e.target.value)}
                className="field"
              >
                <option value="">Sem invernada</option>
                {Array.from(invernadas.entries()).map(([id, descricao]) => (
                  <option key={id} value={id}>
                    {descricao}
                  </option>
                ))}
              </select>
            </label>
            <div className="flex gap-3">
              <Button loading={processando} onClick={confirmarMover} className="flex-1">
                Confirmar
              </Button>
              <Button variant="secondary" onClick={() => setModalMover(false)}>
                Cancelar
              </Button>
            </div>
          </Card>
        </div>
      )}

      {modalBaixa && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-40 p-4">
          <Card className="w-full max-w-sm p-6">
            <h2 className="font-display text-lg font-semibold text-text mb-4">
              Dar baixa em {selecionados.size} animal(is)
            </h2>
            <label className="flex flex-col gap-1.5 mb-5">
              <span className="text-xs font-semibold text-text">Motivo</span>
              <select
                value={motivoBaixa}
                onChange={(e) => setMotivoBaixa(e.target.value as MotivoBaixa)}
                className="field"
              >
                {MOTIVOS.map((m) => (
                  <option key={m} value={m}>
                    {m}
                  </option>
                ))}
              </select>
            </label>
            <div className="flex gap-3">
              <Button
                variant="danger-solid"
                loading={processando}
                onClick={confirmarBaixaLote}
                className="flex-1"
              >
                Confirmar baixa
              </Button>
              <Button variant="secondary" onClick={() => setModalBaixa(false)}>
                Cancelar
              </Button>
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}
