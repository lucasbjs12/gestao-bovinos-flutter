"use client";

import { Suspense, useEffect, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { AlertCircle, CheckCircle2, MailCheck } from "lucide-react";
import { backendAuth } from "@/lib/backend-auth";
import { ApiException } from "@/lib/api-exception";
import { AuthShell, AuthBrand } from "@/components/AuthCard";
import { Button } from "@/components/ui/Button";

type Estado = "verificando" | "sucesso" | "erro" | "sem-token";

function VerificarEmailConteudo() {
  const token = useSearchParams().get("token");
  const [estado, setEstado] = useState<Estado>(token ? "verificando" : "sem-token");
  const [erro, setErro] = useState<string | null>(null);

  useEffect(() => {
    if (!token) return;
    backendAuth
      .verificarEmail(token)
      .then(() => setEstado("sucesso"))
      .catch((err) => {
        setErro(
          err instanceof ApiException
            ? err.message
            : "Erro ao verificar o e-mail. Tente novamente."
        );
        setEstado("erro");
      });
  }, [token]);

  return (
    <AuthShell>
      <AuthBrand />
      <div className="w-14 h-14 rounded-2xl bg-g50 flex items-center justify-center text-g800 mx-auto mb-6">
        <MailCheck size={26} />
      </div>
      <h1 className="font-display text-2xl font-semibold text-text text-center mb-1.5">
        Confirmar e-mail
      </h1>

      {estado === "verificando" && (
        <p className="text-center text-sm text-muted mt-4">Verificando seu e-mail…</p>
      )}

      {estado === "sucesso" && (
        <div className="flex items-start gap-2 bg-g50 rounded-xl px-3.5 py-3 text-sm text-g800 mt-4">
          <CheckCircle2 size={16} className="shrink-0 mt-0.5" />
          E-mail confirmado com sucesso!
        </div>
      )}

      {estado === "erro" && (
        <div className="flex items-start gap-2 bg-danger-bg rounded-xl px-3.5 py-2.5 text-sm text-danger mt-4">
          <AlertCircle size={16} className="shrink-0 mt-0.5" />
          {erro}
        </div>
      )}

      {estado === "sem-token" && (
        <div className="flex items-start gap-2 bg-danger-bg rounded-xl px-3.5 py-2.5 text-sm text-danger mt-4">
          <AlertCircle size={16} className="shrink-0 mt-0.5" />
          Link inválido — falta o token de verificação.
        </div>
      )}

      <Button className="w-full mt-6" onClick={() => (window.location.href = "/inicio")}>
        Ir para o painel
      </Button>

      <p className="text-center text-[13px] text-muted mt-6">
        <Link href="/login" className="text-g800 font-semibold">
          ← Voltar para o login
        </Link>
      </p>
    </AuthShell>
  );
}

export default function VerificarEmailPage() {
  return (
    <Suspense fallback={null}>
      <VerificarEmailConteudo />
    </Suspense>
  );
}
