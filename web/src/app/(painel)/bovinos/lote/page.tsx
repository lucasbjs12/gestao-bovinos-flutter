"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { AlertCircle, Plus, Trash2, ArchiveX } from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { bovinosApi, CategoriaBovino } from "@/lib/api/bovinos";
import { invernadasApi } from "@/lib/api/invernadas";
import { buscarTodasPaginas } from "@/lib/api/pagination";
import { ApiException } from "@/lib/api-exception";
import { PageHeader } from "@/components/ui/PageHeader";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Badge } from "@/components/ui/Badge";
import { FormField } from "@/components/ui/FormField";
import { EmptyState } from "@/components/ui/EmptyState";

const CATEGORIAS: CategoriaBovino[] = [
  "Vaca",
  "Novilha",
  "Terneira",
  "Terneiro",
  "Novilho",
  "Touro",
  "Boi",
];

interface ItemLote {
  brinco: string;
  categoria: CategoriaBovino;
  peso: string;
  dataNascimento: string;
}

interface InvernadaOpcao {
  id: string;
  descricao: string;
}

function draftKey(fazendaId: string) {
  return `draft_cadastro_lote_${fazendaId}`;
}

export default function CadastroLotePage() {
  const { fazendaId } = useAuth();
  const router = useRouter();

  const [invernadas, setInvernadas] = useState<InvernadaOpcao[]>([]);
  const [invernadaId, setInvernadaId] = useState("");

  const [brinco, setBrinco] = useState("");
  const [categoria, setCategoria] = useState<CategoriaBovino>(CATEGORIAS[0]);
  const [peso, setPeso] = useState("");
  const [dataNascimento, setDataNascimento] = useState("");

  const [lote, setLote] = useState<ItemLote[]>([]);
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const [erros, setErros] = useState<string[]>([]);

  useEffect(() => {
    if (!fazendaId) return;
    buscarTodasPaginas((page) => invernadasApi.listar(fazendaId, { page, pageSize: 100 })).then(
      (todas) => setInvernadas(todas.map((inv) => ({ id: inv.id, descricao: inv.descricao })))
    );
    const salvo = localStorage.getItem(draftKey(fazendaId));
    if (salvo) {
      try {
        const draft = JSON.parse(salvo);
        // eslint-disable-next-line react-hooks/set-state-in-effect
        setLote(draft.lote ?? []);
        setInvernadaId(draft.invernadaId ?? "");
      } catch {
        // rascunho corrompido, ignora
      }
    }
  }, [fazendaId]);

  useEffect(() => {
    if (!fazendaId) return;
    if (lote.length === 0) {
      localStorage.removeItem(draftKey(fazendaId));
    } else {
      localStorage.setItem(draftKey(fazendaId), JSON.stringify({ lote, invernadaId }));
    }
  }, [fazendaId, lote, invernadaId]);

  function adicionar() {
    setErro(null);
    if (!brinco.trim()) return setErro("Informe o brinco.");
    if (lote.some((i) => i.brinco === brinco.trim())) {
      return setErro("Este brinco já foi adicionado ao lote.");
    }
    setLote((prev) => [
      ...prev,
      {
        brinco: brinco.trim(),
        categoria,
        peso: peso.trim(),
        dataNascimento,
      },
    ]);
    setBrinco("");
    setPeso("");
    setDataNascimento("");
    // categoria permanece selecionada, igual ao app
  }

  function remover(brincoRemover: string) {
    setLote((prev) => prev.filter((i) => i.brinco !== brincoRemover));
  }

  async function salvarLote() {
    if (!fazendaId || lote.length === 0) return;
    setSalvando(true);
    setErros([]);
    const falhas: string[] = [];
    const sucesso: string[] = [];
    for (const item of lote) {
      try {
        await bovinosApi.criar(fazendaId, {
          numeroBrinco: item.brinco,
          categoria: item.categoria,
          pesoAtualKg: item.peso ? Number(item.peso) : null,
          dataNascimento: item.dataNascimento || null,
          invernadaId: invernadaId || null,
        });
        sucesso.push(item.brinco);
      } catch (err) {
        falhas.push(
          `${item.brinco}: ${err instanceof ApiException ? err.message : "erro ao salvar"}`
        );
      }
    }
    setLote((prev) => prev.filter((i) => !sucesso.includes(i.brinco)));
    setSalvando(false);
    if (falhas.length === 0) {
      localStorage.removeItem(draftKey(fazendaId));
      router.push("/bovinos");
    } else {
      setErros(falhas);
    }
  }

  const semPeso = lote.filter((i) => !i.peso).length;

  return (
    <div className="max-w-2xl">
      <PageHeader
        title="Cadastro em lote"
        subtitle="Adicione vários animais de uma vez, todos para a mesma invernada"
      />

      {erros.length > 0 && (
        <div className="flex flex-col gap-1 bg-danger-bg rounded-lg px-3.5 py-2.5 text-sm text-danger mb-4">
          <span className="font-semibold flex items-center gap-2">
            <AlertCircle size={16} />
            Alguns animais não foram salvos:
          </span>
          {erros.map((e) => (
            <span key={e} className="text-xs">
              {e}
            </span>
          ))}
        </div>
      )}

      <Card className="p-6 mb-5">
        <FormField label="Invernada (aplicada a todos os animais do lote)">
          <select
            value={invernadaId}
            onChange={(e) => setInvernadaId(e.target.value)}
            className="field mb-5"
          >
            <option value="">Sem invernada</option>
            {invernadas.map((inv) => (
              <option key={inv.id} value={inv.id}>
                {inv.descricao}
              </option>
            ))}
          </select>
        </FormField>

        {erro && (
          <div className="flex items-start gap-2 bg-danger-bg rounded-lg px-3.5 py-2.5 text-sm text-danger mb-4">
            <AlertCircle size={16} className="shrink-0 mt-0.5" />
            {erro}
          </div>
        )}

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-4">
          <FormField label="Brinco *">
            <input
              value={brinco}
              onChange={(e) => setBrinco(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && (e.preventDefault(), adicionar())}
              className="field"
              autoFocus
            />
          </FormField>
          <FormField label="Categoria *">
            <select
              value={categoria}
              onChange={(e) => setCategoria(e.target.value as CategoriaBovino)}
              className="field"
            >
              {CATEGORIAS.map((c) => (
                <option key={c} value={c}>
                  {c}
                </option>
              ))}
            </select>
          </FormField>
          <FormField label="Peso (kg)">
            <input
              type="number"
              step="0.1"
              value={peso}
              onChange={(e) => setPeso(e.target.value)}
              className="field"
            />
          </FormField>
          <FormField label="Data de nascimento">
            <input
              type="date"
              value={dataNascimento}
              onChange={(e) => setDataNascimento(e.target.value)}
              className="field"
            />
          </FormField>
        </div>

        <Button onClick={adicionar} icon={<Plus size={15} />} className="w-full">
          Adicionar animal
        </Button>
      </Card>

      <div className="flex items-center justify-between mb-3">
        <span className="text-sm font-semibold text-text">
          {lote.length} {lote.length === 1 ? "animal" : "animais"} no lote
        </span>
        {semPeso > 0 && (
          <span className="text-xs font-semibold text-danger">{semPeso} sem peso</span>
        )}
      </div>

      <Card className="overflow-hidden mb-5">
        {lote.length === 0 ? (
          <EmptyState
            icon={<ArchiveX size={20} />}
            title="Nenhum animal adicionado ainda"
            description="Preencha o formulário acima e clique em Adicionar animal."
          />
        ) : (
          <div className="divide-y divide-border-soft">
            {lote.map((item) => (
              <div key={item.brinco} className="flex items-center justify-between px-5 py-3">
                <div className="flex items-center gap-3">
                  <span className="font-mono font-bold text-sm">{item.brinco}</span>
                  <Badge tone="green">{item.categoria}</Badge>
                  <span className="text-xs text-muted">
                    {item.peso ? `${item.peso} kg` : "sem peso"}
                  </span>
                </div>
                <button
                  onClick={() => remover(item.brinco)}
                  className="p-1.5 rounded-md text-muted-2 hover:text-danger hover:bg-danger-bg transition-colors"
                  aria-label="Remover"
                >
                  <Trash2 size={14} />
                </button>
              </div>
            ))}
          </div>
        )}
      </Card>

      <div className="flex gap-3">
        <Button
          onClick={salvarLote}
          loading={salvando}
          disabled={lote.length === 0}
          className="flex-1"
        >
          {salvando ? "Salvando…" : `Salvar ${lote.length || ""} animais`}
        </Button>
        <Button variant="secondary" onClick={() => router.push("/bovinos")}>
          Cancelar
        </Button>
      </div>
    </div>
  );
}
