"use client";

import { useEffect, useState, FormEvent } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { AlertCircle, Trash2, ArrowDownCircle, Syringe, Baby, Link2Off } from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { bovinosApi, CategoriaBovino, MotivoBaixa } from "@/lib/api/bovinos";
import { invernadasApi } from "@/lib/api/invernadas";
import { eventosApi } from "@/lib/api/eventos";
import { buscarTodasPaginas } from "@/lib/api/pagination";
import { ApiException } from "@/lib/api-exception";
import { campoVisivel } from "@/lib/campos-bovino";
import { PageHeader } from "@/components/ui/PageHeader";
import { Card, CardHeader } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Badge } from "@/components/ui/Badge";
import { FormField } from "@/components/ui/FormField";
import { EmptyState, Spinner } from "@/components/ui/EmptyState";
import { BovinoPhoto } from "@/components/ui/BovinoPhoto";

const MOTIVOS: MotivoBaixa[] = ["Venda", "Morte", "Furto", "Outros"];

const CATEGORIAS: CategoriaBovino[] = [
  "Vaca",
  "Novilha",
  "Novilho",
  "Terneiro",
  "Terneira",
  "Touro",
  "Boi",
];

interface Evento {
  id: string;
  tipo: string;
  dataEvento?: string | null;
}

interface BovinoResumo {
  id: string;
  numeroBrinco: string;
  nomeAnimal?: string | null;
}

export default function DetalheBovinoPage() {
  const { id } = useParams<{ id: string }>();
  const { fazendaId, souDono } = useAuth();
  const router = useRouter();

  const [carregando, setCarregando] = useState(true);
  const [status, setStatus] = useState("Ativo");
  const [numeroBrinco, setNumeroBrinco] = useState("");
  const [nomeAnimal, setNomeAnimal] = useState("");
  const [raca, setRaca] = useState("");
  const [categoria, setCategoria] = useState<CategoriaBovino | "">("");
  const [peso, setPeso] = useState("");
  const [foto, setFoto] = useState<string | null>(null);
  const [invernadaId, setInvernadaId] = useState("");
  const [observacoes, setObservacoes] = useState("");
  const [codigoEpc, setCodigoEpc] = useState("");
  const [estaDeCria, setEstaDeCria] = useState(false);
  const [invernadas, setInvernadas] = useState<{ id: string; descricao: string }[]>([]);
  const [historico, setHistorico] = useState<Evento[]>([]);

  const [mae, setMae] = useState<BovinoResumo | null>(null);
  const [filho, setFilho] = useState<BovinoResumo | null>(null);
  const [mostrarVincular, setMostrarVincular] = useState(false);
  const [brincoBusca, setBrincoBusca] = useState("");
  const [encontrado, setEncontrado] = useState<BovinoResumo | null>(null);
  const [buscou, setBuscou] = useState(false);
  const [vinculando, setVinculando] = useState(false);

  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  const [mostrarBaixa, setMostrarBaixa] = useState(false);
  const [motivoBaixa, setMotivoBaixa] = useState<MotivoBaixa>(MOTIVOS[0]);
  const [obsBaixa, setObsBaixa] = useState("");

  const [campos, setCampos] = useState({
    nomeAnimal: true,
    raca: true,
    pesoAtual: true,
    invernada: true,
    observacoes: true,
    codigoEpc: true,
  });

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setCampos({
      nomeAnimal: campoVisivel("nomeAnimal"),
      raca: campoVisivel("raca"),
      pesoAtual: campoVisivel("pesoAtual"),
      invernada: campoVisivel("invernada"),
      observacoes: campoVisivel("observacoes"),
      codigoEpc: campoVisivel("codigoEpc"),
    });
  }, []);

  async function carregar() {
    if (!fazendaId || !id) return;
    const bovino = await bovinosApi.buscarPorId(fazendaId, id);
    setStatus(bovino.status ?? "Ativo");
    setNumeroBrinco(bovino.numeroBrinco ?? "");
    setNomeAnimal(bovino.nomeAnimal ?? "");
    setRaca(bovino.raca ?? "");
    setCategoria(bovino.categoria ?? "");
    setPeso(bovino.pesoAtualKg != null ? String(bovino.pesoAtualKg) : "");
    setFoto(bovino.foto ?? null);
    setInvernadaId(bovino.invernadaId ?? "");
    setObservacoes(bovino.observacoes ?? "");
    setCodigoEpc(bovino.codigoEpc ?? "");
    setEstaDeCria(!!bovino.estaDeCria);
    setMae(bovino.mae ? { id: bovino.mae.id, numeroBrinco: bovino.mae.numeroBrinco, nomeAnimal: bovino.mae.nomeAnimal } : null);

    const todasInvernadas = await buscarTodasPaginas((page) =>
      invernadasApi.listar(fazendaId, { page, pageSize: 100 })
    );
    setInvernadas(todasInvernadas.map((inv) => ({ id: inv.id, descricao: inv.descricao })));

    const todosEventos = await buscarTodasPaginas((page) =>
      eventosApi.listar(fazendaId, { page, pageSize: 100 })
    );
    setHistorico(
      todosEventos
        .filter((e) => e.bovinos.some((b) => b.bovinoId === id))
        .sort((a, b) => (b.dataEvento ?? "").localeCompare(a.dataEvento ?? ""))
        .map((e) => ({ id: e.id, tipo: e.tipo, dataEvento: e.dataEvento }))
    );

    if (bovino.estaDeCria) {
      const todosBovinos = await buscarTodasPaginas((page) =>
        bovinosApi.listar(fazendaId, { page, pageSize: 100 })
      );
      const f = todosBovinos.find((b) => b.idMae === id && b.status === "Ativo");
      setFilho(f ? { id: f.id, numeroBrinco: f.numeroBrinco, nomeAnimal: f.nomeAnimal } : null);
    } else {
      setFilho(null);
    }

    setCarregando(false);
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
  }, [fazendaId, id]);

  async function salvar(e: FormEvent) {
    e.preventDefault();
    if (!fazendaId) return;
    if (!categoria) {
      setErro("Selecione a categoria.");
      return;
    }
    setErro(null);
    setSalvando(true);
    try {
      await bovinosApi.atualizar(fazendaId, id, {
        numeroBrinco: numeroBrinco.trim(),
        nomeAnimal: nomeAnimal.trim() || null,
        raca: raca.trim() || null,
        categoria,
        pesoAtualKg: peso ? Number(peso) : null,
        observacoes: observacoes.trim() || null,
        invernadaId: invernadaId || null,
        estaDeCria,
        codigoEpc: codigoEpc.trim() || null,
      });
      router.push("/bovinos");
    } catch (err) {
      setErro(
        err instanceof ApiException ? err.message : "Não foi possível salvar. Tente novamente."
      );
    } finally {
      setSalvando(false);
    }
  }

  async function confirmarBaixa() {
    if (!fazendaId) return;
    if (!confirm(`Dar baixa em ${numeroBrinco} por "${motivoBaixa}"?`)) return;
    const hoje = new Date().toISOString().slice(0, 10);
    try {
      await bovinosApi.darBaixa(fazendaId, id, {
        motivo: motivoBaixa,
        observacoes: obsBaixa.trim() || null,
        dataBaixa: hoje,
      });
      router.push("/bovinos");
    } catch (err) {
      alert(err instanceof ApiException ? err.message : "Não foi possível dar baixa.");
    }
  }

  async function remover() {
    if (!fazendaId) return;
    if (!confirm(`Excluir o bovino ${numeroBrinco}? Essa ação não pode ser desfeita.`))
      return;
    await bovinosApi.excluir(fazendaId, id);
    router.push("/bovinos");
  }

  async function buscarTerneiro() {
    if (!fazendaId || !brincoBusca.trim()) return;
    setBuscou(true);
    const alvo = brincoBusca.trim();
    const { itens } = await bovinosApi.listar(fazendaId, { busca: alvo, pageSize: 100 });
    const achado = itens.find((b) => b.numeroBrinco === alvo);
    setEncontrado(achado ? { id: achado.id, numeroBrinco: achado.numeroBrinco, nomeAnimal: achado.nomeAnimal } : null);
  }

  async function confirmarVincular() {
    if (!fazendaId) return;
    setVinculando(true);
    try {
      if (encontrado) {
        await bovinosApi.atualizar(fazendaId, encontrado.id, { idMae: id });
      } else {
        if (
          !confirm(
            `Nenhum animal com brinco ${brincoBusca} foi encontrado. Deseja criar esse cadastro e vincular a esta mãe?`
          )
        )
          return;
        await bovinosApi.criar(fazendaId, {
          numeroBrinco: brincoBusca.trim(),
          raca: raca || null,
          invernadaId: invernadaId || null,
          idMae: id,
          categoria: "Terneiro",
        });
      }
      setMostrarVincular(false);
      setBrincoBusca("");
      setEncontrado(null);
      setBuscou(false);
      carregar();
    } catch (err) {
      alert(err instanceof ApiException ? err.message : "Não foi possível vincular.");
    } finally {
      setVinculando(false);
    }
  }

  async function desvincular() {
    if (!fazendaId || !filho) return;
    if (
      !confirm(
        `O vínculo com ${filho.numeroBrinco} será removido. O terneiro não será excluído.`
      )
    )
      return;
    await bovinosApi.atualizar(fazendaId, filho.id, { idMae: null });
    carregar();
  }

  if (carregando) {
    return (
      <Card>
        <Spinner />
      </Card>
    );
  }

  return (
    <div className="max-w-xl">
      <PageHeader
        title={numeroBrinco}
        subtitle={nomeAnimal || undefined}
        action={
          <>
            {status !== "Ativo" && <Badge tone="gray">{status}</Badge>}
            {souDono && (
              <Button variant="danger" size="sm" icon={<Trash2 size={13} />} onClick={remover}>
                Excluir
              </Button>
            )}
          </>
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
          <BovinoPhoto
            foto={foto}
            alt={`Foto do bovino ${numeroBrinco}`}
            size="lg"
          />

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <FormField label="Número do brinco *">
              <input value={numeroBrinco} onChange={(e) => setNumeroBrinco(e.target.value)} className="field" />
            </FormField>
            {campos.nomeAnimal && (
              <FormField label="Nome">
                <input value={nomeAnimal} onChange={(e) => setNomeAnimal(e.target.value)} className="field" />
              </FormField>
            )}
            {campos.raca && (
              <FormField label="Raça">
                <input value={raca} onChange={(e) => setRaca(e.target.value)} className="field" />
              </FormField>
            )}
            <FormField label="Categoria *">
              <select
                value={categoria}
                onChange={(e) => setCategoria(e.target.value as CategoriaBovino)}
                className="field"
              >
                <option value="">Selecione…</option>
                {CATEGORIAS.map((c) => (
                  <option key={c} value={c}>{c}</option>
                ))}
              </select>
            </FormField>
            {campos.pesoAtual && (
              <FormField label="Peso atual (kg)">
                <input type="number" step="0.1" value={peso} onChange={(e) => setPeso(e.target.value)} className="field" />
              </FormField>
            )}
          </div>
          {campos.invernada && (
            <FormField label="Invernada">
              <select value={invernadaId} onChange={(e) => setInvernadaId(e.target.value)} className="field">
                <option value="">Sem invernada</option>
                {invernadas.map((inv) => (
                  <option key={inv.id} value={inv.id}>{inv.descricao}</option>
                ))}
              </select>
            </FormField>
          )}
          {(categoria === "Vaca" || categoria === "Novilha") && (
            <label className="flex items-center gap-2.5 text-sm text-text">
              <input
                type="checkbox"
                checked={estaDeCria}
                onChange={(e) => setEstaDeCria(e.target.checked)}
                className="w-4 h-4 accent-g700"
              />
              É de cria (fêmea reprodutora)
            </label>
          )}
          {campos.codigoEpc && (
            <FormField label="Código EPC (RFID)" hint="Usado na leitura por aproximação de tag NFC/RFID">
              <input value={codigoEpc} onChange={(e) => setCodigoEpc(e.target.value)} className="field" />
            </FormField>
          )}
          {campos.observacoes && (
            <FormField label="Observações">
              <textarea value={observacoes} onChange={(e) => setObservacoes(e.target.value)} rows={3} className="field resize-none" />
            </FormField>
          )}

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

      {mae && (
        <Card className="p-5 mb-5">
          <div className="text-[11px] font-bold uppercase tracking-wider text-muted mb-2">
            Vaca mãe
          </div>
          <Link href={`/bovinos/${mae.id}`} className="text-sm font-semibold text-g800 hover:underline">
            {mae.numeroBrinco} {mae.nomeAnimal && `· ${mae.nomeAnimal}`}
          </Link>
        </Card>
      )}

      {estaDeCria && (
        <Card className="p-5 mb-5">
          <div className="text-[11px] font-bold uppercase tracking-wider text-muted mb-3">
            Terneiro vinculado
          </div>
          {filho ? (
            <div className="flex items-center justify-between">
              <Link href={`/bovinos/${filho.id}`} className="text-sm font-semibold text-g800 hover:underline">
                {filho.numeroBrinco} {filho.nomeAnimal && `· ${filho.nomeAnimal}`}
              </Link>
              <Button variant="danger" size="sm" icon={<Link2Off size={13} />} onClick={desvincular}>
                Desvincular
              </Button>
            </div>
          ) : !mostrarVincular ? (
            <div className="flex items-center justify-between">
              <span className="text-sm text-muted">Nenhum terneiro vinculado</span>
              <Button
                variant="secondary"
                size="sm"
                icon={<Baby size={13} />}
                onClick={() => setMostrarVincular(true)}
              >
                Informar brinco do terneiro
              </Button>
            </div>
          ) : (
            <div className="flex flex-col gap-3">
              <div className="flex gap-2">
                <input
                  value={brincoBusca}
                  onChange={(e) => {
                    setBrincoBusca(e.target.value);
                    setBuscou(false);
                  }}
                  placeholder="Brinco do terneiro"
                  className="field"
                />
                <Button variant="secondary" onClick={buscarTerneiro} className="shrink-0">
                  Buscar
                </Button>
              </div>
              {buscou && (
                <div className="text-xs text-muted">
                  {encontrado
                    ? `Encontrado: ${encontrado.numeroBrinco}${encontrado.nomeAnimal ? ` · ${encontrado.nomeAnimal}` : ""}`
                    : "Nenhum animal encontrado — será criado um novo cadastro."}
                </div>
              )}
              {buscou && (
                <div className="flex gap-3">
                  <Button loading={vinculando} onClick={confirmarVincular} size="sm">
                    {encontrado ? "Vincular" : "Criar e vincular"}
                  </Button>
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={() => {
                      setMostrarVincular(false);
                      setBrincoBusca("");
                      setBuscou(false);
                    }}
                  >
                    Cancelar
                  </Button>
                </div>
              )}
            </div>
          )}
        </Card>
      )}

      {status === "Ativo" && souDono && (
        <Card className="p-6 mb-5">
          {!mostrarBaixa ? (
            <Button
              variant="danger"
              size="sm"
              icon={<ArrowDownCircle size={14} />}
              onClick={() => setMostrarBaixa(true)}
            >
              Dar baixa neste animal
            </Button>
          ) : (
            <div className="flex flex-col gap-4">
              <FormField label="Motivo">
                <select value={motivoBaixa} onChange={(e) => setMotivoBaixa(e.target.value as MotivoBaixa)} className="field">
                  {MOTIVOS.map((m) => (
                    <option key={m} value={m}>{m}</option>
                  ))}
                </select>
              </FormField>
              <FormField label="Observações">
                <textarea value={obsBaixa} onChange={(e) => setObsBaixa(e.target.value)} rows={2} className="field resize-none" />
              </FormField>
              <div className="flex gap-3">
                <Button variant="danger-solid" onClick={confirmarBaixa}>
                  Confirmar baixa
                </Button>
                <Button variant="secondary" onClick={() => setMostrarBaixa(false)}>
                  Cancelar
                </Button>
              </div>
            </div>
          )}
        </Card>
      )}

      <Card className="overflow-hidden">
        <CardHeader title={`Histórico sanitário (${historico.length})`} />
        {historico.length === 0 ? (
          <EmptyState
            icon={<Syringe size={20} />}
            title="Nenhum evento registrado"
            description="Os manejos sanitários deste animal aparecem aqui."
          />
        ) : (
          <div className="divide-y divide-border-soft">
            {historico.map((e) => (
              <div key={e.id} className="px-5 py-3 text-sm flex items-center justify-between">
                <Badge tone="green">{e.tipo}</Badge>
                <span className="text-muted text-xs">{e.dataEvento ?? "sem data"}</span>
              </div>
            ))}
          </div>
        )}
      </Card>
    </div>
  );
}
