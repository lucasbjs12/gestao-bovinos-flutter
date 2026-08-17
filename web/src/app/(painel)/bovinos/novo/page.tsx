"use client";

import { useEffect, useState, FormEvent } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { AlertCircle, Crown } from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { bovinosApi, CategoriaBovino } from "@/lib/api/bovinos";
import { invernadasApi } from "@/lib/api/invernadas";
import { buscarTodasPaginas } from "@/lib/api/pagination";
import { ApiException } from "@/lib/api-exception";
import { campoVisivel } from "@/lib/campos-bovino";
import { PageHeader } from "@/components/ui/PageHeader";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { FormField } from "@/components/ui/FormField";

const CATEGORIAS: CategoriaBovino[] = [
  "Vaca",
  "Novilha",
  "Novilho",
  "Terneiro",
  "Terneira",
  "Touro",
  "Boi",
];

interface InvernadaOpcao {
  id: string;
  descricao: string;
}

export default function NovoBovinoPage() {
  const { fazendaId } = useAuth();
  const router = useRouter();

  const [numeroBrinco, setNumeroBrinco] = useState("");
  const [nomeAnimal, setNomeAnimal] = useState("");
  const [raca, setRaca] = useState("");
  const [categoria, setCategoria] = useState<CategoriaBovino | "">("");
  const [peso, setPeso] = useState("");
  const [invernadaId, setInvernadaId] = useState("");
  const [observacoes, setObservacoes] = useState("");
  const [codigoEpc, setCodigoEpc] = useState("");
  const [invernadas, setInvernadas] = useState<InvernadaOpcao[]>([]);
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const [limiteAtingido, setLimiteAtingido] = useState(false);
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

  useEffect(() => {
    if (!fazendaId) return;
    buscarTodasPaginas((page) => invernadasApi.listar(fazendaId, { page, pageSize: 100 })).then(
      (todas) => setInvernadas(todas.map((inv) => ({ id: inv.id, descricao: inv.descricao })))
    );
  }, [fazendaId]);

  async function salvar(e: FormEvent) {
    e.preventDefault();
    if (!fazendaId) return;
    if (!numeroBrinco.trim()) {
      setErro("Informe o número do brinco.");
      return;
    }
    if (!categoria) {
      setErro("Selecione a categoria.");
      return;
    }
    setErro(null);
    setLimiteAtingido(false);
    setSalvando(true);
    try {
      await bovinosApi.criar(fazendaId, {
        numeroBrinco: numeroBrinco.trim(),
        nomeAnimal: nomeAnimal.trim() || null,
        raca: raca.trim() || null,
        categoria,
        pesoAtualKg: peso ? Number(peso) : null,
        observacoes: observacoes.trim() || null,
        invernadaId: invernadaId || null,
        codigoEpc: codigoEpc.trim() || null,
      });
      router.push("/bovinos");
    } catch (err) {
      if (err instanceof ApiException && err.codigo === "limite_do_plano_atingido") {
        setLimiteAtingido(true);
        setErro(err.message);
      } else {
        setErro(
          err instanceof ApiException ? err.message : "Não foi possível salvar. Tente novamente."
        );
      }
    } finally {
      setSalvando(false);
    }
  }

  return (
    <div className="max-w-xl">
      <PageHeader title="Novo bovino" subtitle="Adicione um animal ao rebanho" />

      <Card className="p-6">
        <form onSubmit={salvar} className="flex flex-col gap-4">
          {erro && !limiteAtingido && (
            <div className="flex items-start gap-2 bg-danger-bg rounded-lg px-3.5 py-2.5 text-sm text-danger">
              <AlertCircle size={16} className="shrink-0 mt-0.5" />
              {erro}
            </div>
          )}
          {limiteAtingido && (
            <div className="flex flex-col gap-2.5 bg-gold-50 border border-gold rounded-lg px-4 py-3.5">
              <div className="flex items-start gap-2 text-sm text-text">
                <Crown size={16} className="shrink-0 mt-0.5 text-gold" />
                {erro}
              </div>
              <Link
                href="/planos"
                className="text-xs font-semibold text-g800 hover:underline self-start"
              >
                Ver planos →
              </Link>
            </div>
          )}

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <FormField label="Número do brinco *">
              <input
                value={numeroBrinco}
                onChange={(e) => setNumeroBrinco(e.target.value)}
                className="field"
                autoFocus
              />
            </FormField>
            {campos.nomeAnimal && (
              <FormField label="Nome">
                <input
                  value={nomeAnimal}
                  onChange={(e) => setNomeAnimal(e.target.value)}
                  className="field"
                />
              </FormField>
            )}
            {campos.raca && (
              <FormField label="Raça">
                <input
                  value={raca}
                  onChange={(e) => setRaca(e.target.value)}
                  className="field"
                />
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
                  <option key={c} value={c}>
                    {c}
                  </option>
                ))}
              </select>
            </FormField>
            {campos.pesoAtual && (
              <FormField label="Peso atual (kg)">
                <input
                  type="number"
                  step="0.1"
                  value={peso}
                  onChange={(e) => setPeso(e.target.value)}
                  className="field"
                />
              </FormField>
            )}
          </div>

          {campos.invernada && (
            <FormField label="Invernada">
              <select
                value={invernadaId}
                onChange={(e) => setInvernadaId(e.target.value)}
                className="field"
              >
                <option value="">Sem invernada</option>
                {invernadas.map((inv) => (
                  <option key={inv.id} value={inv.id}>
                    {inv.descricao}
                  </option>
                ))}
              </select>
            </FormField>
          )}

          {campos.codigoEpc && (
            <FormField label="Código EPC (RFID)" hint="Usado na leitura por aproximação de tag NFC/RFID">
              <input
                value={codigoEpc}
                onChange={(e) => setCodigoEpc(e.target.value)}
                className="field"
              />
            </FormField>
          )}

          {campos.observacoes && (
            <FormField label="Observações">
              <textarea
                value={observacoes}
                onChange={(e) => setObservacoes(e.target.value)}
                rows={3}
                className="field resize-none"
              />
            </FormField>
          )}

          <div className="flex gap-3 mt-2">
            <Button type="submit" loading={salvando} className="flex-1">
              {salvando ? "Salvando…" : "Salvar bovino"}
            </Button>
            <Button type="button" variant="secondary" onClick={() => router.back()}>
              Cancelar
            </Button>
          </div>
        </form>
      </Card>
    </div>
  );
}
