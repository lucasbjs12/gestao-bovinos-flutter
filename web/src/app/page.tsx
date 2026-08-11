import type { Metadata } from "next";
import LandingContent from "./LandingContent";

export const metadata: Metadata = {
  title: "Gestão de Rebanho — Controle inteligente do seu gado",
  description:
    "Aplicativo completo para gestão de rebanho bovino. Cadastro de animais, invernadas, manejo sanitário e muito mais. Funciona offline.",
};

export default function Page() {
  return <LandingContent />;
}
