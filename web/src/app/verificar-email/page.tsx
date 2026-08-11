"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

/// O backend próprio não tem fluxo de verificação de e-mail (ver
/// backend/README.md, Fase 8) -- rota mantida só pra não quebrar links
/// antigos, redireciona direto pro painel.
export default function VerificarEmailPage() {
  const router = useRouter();

  useEffect(() => {
    router.replace("/inicio");
  }, [router]);

  return null;
}
