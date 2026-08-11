"use client";

import { useState, FormEvent } from "react";
import { useRouter } from "next/navigation";
import { AlertCircle } from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { invernadasApi } from "@/lib/api/invernadas";
import { PageHeader } from "@/components/ui/PageHeader";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { FormField } from "@/components/ui/FormField";

export default function NovaInvernadaPage() {
  const { fazendaId } = useAuth();
  const router = useRouter();
  const [descricao, setDescricao] = useState("");
  const [hectares, setHectares] = useState("");
  const [observacoes, setObservacoes] = useState("");
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  async function salvar(e: FormEvent) {
    e.preventDefault();
    if (!fazendaId) return;
    if (!descricao.trim()) {
      setErro("Informe uma descrição para a invernada.");
      return;
    }
    setErro(null);
    setSalvando(true);
    try {
      await invernadasApi.criar(fazendaId, {
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

  return (
    <div className="max-w-lg">
      <PageHeader title="Nova invernada" subtitle="Cadastre uma área de pasto" />

      <Card className="p-6">
        <form onSubmit={salvar} className="flex flex-col gap-4">
          {erro && (
            <div className="flex items-start gap-2 bg-danger-bg rounded-lg px-3.5 py-2.5 text-sm text-danger">
              <AlertCircle size={16} className="shrink-0 mt-0.5" />
              {erro}
            </div>
          )}

          <FormField label="Descrição *">
            <input
              value={descricao}
              onChange={(e) => setDescricao(e.target.value)}
              placeholder="Ex.: Piquete 3"
              className="field"
              autoFocus
            />
          </FormField>

          <FormField label="Hectares">
            <input
              type="number"
              step="0.01"
              value={hectares}
              onChange={(e) => setHectares(e.target.value)}
              placeholder="Ex.: 12.5"
              className="field"
            />
          </FormField>

          <FormField label="Observações">
            <textarea
              value={observacoes}
              onChange={(e) => setObservacoes(e.target.value)}
              rows={3}
              className="field resize-none"
            />
          </FormField>

          <div className="flex gap-3 mt-2">
            <Button type="submit" loading={salvando} className="flex-1">
              {salvando ? "Salvando…" : "Salvar invernada"}
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
