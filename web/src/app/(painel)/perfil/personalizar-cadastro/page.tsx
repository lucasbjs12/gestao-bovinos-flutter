"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Lock, RotateCcw } from "lucide-react";
import {
  CAMPOS_BOVINO,
  CampoBovino,
  campoVisivel,
  salvarCampo,
  restaurarPadrao,
} from "@/lib/campos-bovino";
import { PageHeader } from "@/components/ui/PageHeader";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";

export default function PersonalizarCadastroPage() {
  const router = useRouter();
  const [config, setConfig] = useState<Record<CampoBovino, boolean> | null>(null);

  useEffect(() => {
    const inicial = Object.fromEntries(
      CAMPOS_BOVINO.map(({ campo }) => [campo, campoVisivel(campo)])
    ) as Record<CampoBovino, boolean>;
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setConfig(inicial);
  }, []);

  function toggle(campo: CampoBovino) {
    setConfig((prev) => {
      if (!prev) return prev;
      const novo = { ...prev, [campo]: !prev[campo] };
      salvarCampo(campo, novo[campo]);
      return novo;
    });
  }

  function handleRestaurar() {
    if (!confirm("Restaurar todos os campos para o padrão (todos visíveis)?")) return;
    restaurarPadrao();
    setConfig(
      Object.fromEntries(CAMPOS_BOVINO.map(({ campo }) => [campo, true])) as Record<
        CampoBovino,
        boolean
      >
    );
  }

  return (
    <div className="max-w-lg">
      <PageHeader
        title="Personalizar cadastro"
        subtitle="Escolha quais campos aparecem no cadastro e na edição de bovinos"
      />

      <Card className="overflow-hidden mb-5">
        <div className="flex items-center justify-between px-5 py-4 border-b border-border-soft bg-cream">
          <span className="flex items-center gap-2.5 text-sm font-medium text-text">
            <Lock size={15} className="text-muted-2" />
            Número do brinco / Categoria
          </span>
          <span className="text-xs text-muted-2">sempre visíveis</span>
        </div>
        <div className="divide-y divide-border-soft">
          {CAMPOS_BOVINO.map(({ campo, label }) => (
            <div key={campo} className="flex items-center justify-between px-5 py-3.5">
              <span className="text-sm font-medium text-text">{label}</span>
              <button
                onClick={() => toggle(campo)}
                className={`w-11 h-6 rounded-full transition-colors relative ${
                  config?.[campo] ? "bg-g700" : "bg-border"
                }`}
                aria-label={`Alternar ${label}`}
              >
                <span
                  className={`absolute top-0.5 left-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform ${
                    config?.[campo] ? "translate-x-5" : ""
                  }`}
                />
              </button>
            </div>
          ))}
        </div>
      </Card>

      <div className="flex gap-3">
        <Button variant="secondary" icon={<RotateCcw size={14} />} onClick={handleRestaurar}>
          Restaurar padrão
        </Button>
        <Button variant="secondary" onClick={() => router.back()}>
          Voltar
        </Button>
      </div>
    </div>
  );
}
