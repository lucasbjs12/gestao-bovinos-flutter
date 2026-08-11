"use client";

import { useEffect, useState } from "react";
import { PawPrint, ClipboardList, Sprout, PartyPopper } from "lucide-react";
import { Button } from "@/components/ui/Button";

const CHAVE = "onboarding_shown_v1_web";

const SLIDES = [
  {
    icon: PawPrint,
    titulo: "Bem-vindo ao Gestão de Rebanho",
    texto: "Agora você também gerencia sua fazenda pelo navegador, com os mesmos dados do aplicativo.",
  },
  {
    icon: ClipboardList,
    titulo: "Cadastre seus animais",
    texto: "Brinco, categoria, peso e invernada — individualmente ou em lote, direto do computador.",
  },
  {
    icon: Sprout,
    titulo: "Organize em invernadas",
    texto: "Mova lotes inteiros de uma vez e acompanhe a taxa de lotação (kg/ha) de cada área.",
  },
  {
    icon: PartyPopper,
    titulo: "Tudo pronto!",
    texto: "Os dados sincronizam em tempo real com o aplicativo — o que você faz aqui aparece lá, e vice-versa.",
  },
];

export function Onboarding() {
  const [visivel, setVisivel] = useState(false);
  const [pagina, setPagina] = useState(0);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    if (localStorage.getItem(CHAVE) !== "1") setVisivel(true);
  }, []);

  function fechar() {
    localStorage.setItem(CHAVE, "1");
    setVisivel(false);
  }

  if (!visivel) return null;

  const slide = SLIDES[pagina];
  const Icon = slide.icon;
  const ultima = pagina === SLIDES.length - 1;

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-surface rounded-3xl max-w-sm w-full p-8 shadow-lg">
        <div className="w-16 h-16 rounded-2xl bg-g50 flex items-center justify-center text-g800 mx-auto mb-6">
          <Icon size={30} />
        </div>
        <h2 className="font-display text-xl font-semibold text-text text-center mb-2">
          {slide.titulo}
        </h2>
        <p className="text-sm text-muted text-center leading-relaxed mb-7">
          {slide.texto}
        </p>

        <div className="w-full h-1 bg-border rounded-full mb-1.5 overflow-hidden">
          <div
            className="h-full bg-g700 rounded-full transition-all"
            style={{ width: `${((pagina + 1) / SLIDES.length) * 100}%` }}
          />
        </div>
        <div className="text-center text-[11px] text-muted-2 mb-6">
          {pagina + 1} de {SLIDES.length}
        </div>

        <div className="flex items-center justify-between gap-3">
          {!ultima ? (
            <button onClick={fechar} className="text-xs text-muted hover:text-text">
              Pular
            </button>
          ) : (
            <span />
          )}
          <Button
            size="sm"
            onClick={() => (ultima ? fechar() : setPagina((p) => p + 1))}
          >
            {ultima ? "Começar agora →" : "Próximo"}
          </Button>
        </div>
      </div>
    </div>
  );
}
