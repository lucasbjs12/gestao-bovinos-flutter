"use client";

import { useEffect, useState, FormEvent } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { AlertCircle, Trash2, Users2 } from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { eventosApi, TipoEventoSanitario } from "@/lib/api/eventos";
import { PageHeader } from "@/components/ui/PageHeader";
import { Card, CardHeader } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { FormField } from "@/components/ui/FormField";
import { EmptyState, Spinner } from "@/components/ui/EmptyState";

const TIPOS: { value: TipoEventoSanitario; label: string }[] = [
  { value: "Vacinacao", label: "Vacinação" },
  { value: "Vermifugacao", label: "Vermifugação" },
  { value: "Medicacao", label: "Medicação" },
  { value: "Castracao", label: "Castração" },
  { value: "Banho", label: "Banho" },
  { value: "Outros", label: "Outros" },
];

const LABEL_POR_TIPO = Object.fromEntries(TIPOS.map((t) => [t.value, t.label])) as Record<
  TipoEventoSanitario,
  string
>;

interface Animal {
  id: string;
  numeroBrinco: string;
  nomeAnimal?: string | null;
}

export default function DetalheEventoPage() {
  const { id } = useParams<{ id: string }>();
  const { fazendaId, souDono } = useAuth();
  const router = useRouter();

  const [carregando, setCarregando] = useState(true);
  const [tipo, setTipo] = useState<TipoEventoSanitario>(TIPOS[0].value);
  const [data, setData] = useState("");
  const [produto, setProduto] = useState("");
  const [dosagem, setDosagem] = useState("");
  const [responsavel, setResponsavel] = useState("");
  const [observacoes, setObservacoes] = useState("");
  const [animais, setAnimais] = useState<Animal[]>([]);
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  useEffect(() => {
    if (!fazendaId || !id) return;
    async function carregar() {
      const evento = await eventosApi.buscarPorId(fazendaId!, id);
      setTipo(evento.tipo ?? TIPOS[0].value);
      setData(evento.dataEvento ?? "");
      setProduto(evento.produtoUtilizado ?? "");
      setDosagem(evento.dosagem ?? "");
      setResponsavel(evento.responsavel ?? "");
      setObservacoes(evento.observacoes ?? "");
      setAnimais(
        evento.bovinos
          .filter((b) => b.bovino)
          .map((b) => ({
            id: b.bovino!.id,
            numeroBrinco: b.bovino!.numeroBrinco,
            nomeAnimal: b.bovino!.nomeAnimal,
          }))
      );
      setCarregando(false);
    }
    carregar();
  }, [fazendaId, id]);

  async function salvar(e: FormEvent) {
    e.preventDefault();
    if (!fazendaId) return;
    setErro(null);
    setSalvando(true);
    try {
      await eventosApi.atualizar(fazendaId, id, {
        tipo,
        dataEvento: data || null,
        produtoUtilizado: produto.trim() || null,
        dosagem: dosagem.trim() || null,
        responsavel: responsavel.trim() || null,
        observacoes: observacoes.trim() || null,
      });
      router.push("/eventos");
    } catch {
      setErro("Não foi possível salvar. Tente novamente.");
    } finally {
      setSalvando(false);
    }
  }

  async function remover() {
    if (!fazendaId) return;
    if (!confirm(`Excluir o evento de ${LABEL_POR_TIPO[tipo]}?`)) return;
    await eventosApi.excluir(fazendaId, id);
    router.push("/eventos");
  }

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
        title={LABEL_POR_TIPO[tipo]}
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
              <input type="date" value={data} onChange={(e) => setData(e.target.value)} className="field" />
            </FormField>
            <FormField label="Produto utilizado">
              <input value={produto} onChange={(e) => setProduto(e.target.value)} className="field" />
            </FormField>
            <FormField label="Dosagem">
              <input value={dosagem} onChange={(e) => setDosagem(e.target.value)} className="field" />
            </FormField>
            <FormField label="Responsável">
              <input value={responsavel} onChange={(e) => setResponsavel(e.target.value)} className="field" />
            </FormField>
          </div>
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
        <CardHeader title={`Animais envolvidos (${animais.length})`} />
        {animais.length === 0 ? (
          <EmptyState icon={<Users2 size={20} />} title="Sem animais vinculados" />
        ) : (
          <div className="divide-y divide-border-soft">
            {animais.map((a) => (
              <Link key={a.id} href={`/bovinos/${a.id}`} className="flex items-center gap-2 px-5 py-3 text-sm hover:bg-g50 transition-colors">
                <span className="font-mono font-bold">{a.numeroBrinco}</span>
                {a.nomeAnimal && <span className="text-muted">{a.nomeAnimal}</span>}
              </Link>
            ))}
          </div>
        )}
      </Card>
    </div>
  );
}
