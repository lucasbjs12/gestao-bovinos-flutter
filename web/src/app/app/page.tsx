import type { Metadata } from "next";
import TelasContent from "./TelasContent";

export const metadata: Metadata = {
  title: "O app na rotina diária — Gestão de Rebanho",
  description:
    "Veja como o Gestão de Rebanho funciona no dia a dia do produtor rural: cadastro, controle de animais, invernadas e manejos sanitários.",
};

export default function Page() {
  return <TelasContent />;
}
