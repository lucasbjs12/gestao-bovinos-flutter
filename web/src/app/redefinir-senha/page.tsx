"use client";

import { Suspense, useState, FormEvent } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { AlertCircle, CheckCircle2, KeyRound } from "lucide-react";
import { backendAuth } from "@/lib/backend-auth";
import { ApiException } from "@/lib/api-exception";
import { AuthShell, AuthBrand, Campo, campoClass } from "@/components/AuthCard";
import { Button } from "@/components/ui/Button";

function RedefinirSenhaForm() {
  const router = useRouter();
  const token = useSearchParams().get("token");
  const [senha, setSenha] = useState("");
  const [confirmar, setConfirmar] = useState("");
  const [carregando, setCarregando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const [sucesso, setSucesso] = useState(false);

  async function redefinir(e: FormEvent) {
    e.preventDefault();
    if (!token) return;
    if (senha.length < 8) return setErro("A senha deve ter pelo menos 8 caracteres.");
    if (senha !== confirmar) return setErro("As senhas não coincidem.");

    setErro(null);
    setCarregando(true);
    try {
      await backendAuth.redefinirSenha(token, senha);
      setSucesso(true);
      setTimeout(() => router.push("/login"), 2000);
    } catch (err) {
      setErro(
        err instanceof ApiException
          ? err.message
          : "Erro ao redefinir a senha. Tente novamente."
      );
    } finally {
      setCarregando(false);
    }
  }

  return (
    <AuthShell>
      <AuthBrand />
      <div className="w-14 h-14 rounded-2xl bg-g50 flex items-center justify-center text-g800 mx-auto mb-6">
        <KeyRound size={26} />
      </div>
      <h1 className="font-display text-2xl font-semibold text-text text-center mb-1.5">
        Escolher nova senha
      </h1>

      {!token && (
        <div className="flex items-start gap-2 bg-danger-bg rounded-xl px-3.5 py-2.5 text-sm text-danger mb-4">
          <AlertCircle size={16} className="shrink-0 mt-0.5" />
          Link inválido — falta o token de redefinição. Peça um novo link em
          &quot;Esqueci minha senha&quot;.
        </div>
      )}

      {erro && (
        <div className="flex items-start gap-2 bg-danger-bg rounded-xl px-3.5 py-2.5 text-sm text-danger mb-4">
          <AlertCircle size={16} className="shrink-0 mt-0.5" />
          {erro}
        </div>
      )}

      {sucesso ? (
        <div className="flex items-start gap-2 bg-g50 rounded-xl px-3.5 py-3 text-sm text-g800">
          <CheckCircle2 size={16} className="shrink-0 mt-0.5" />
          Senha redefinida! Levando você pro login…
        </div>
      ) : (
        token && (
          <form onSubmit={redefinir} className="flex flex-col gap-4">
            <Campo label="Nova senha">
              <input
                type="password"
                value={senha}
                onChange={(e) => setSenha(e.target.value)}
                className={campoClass}
              />
            </Campo>
            <Campo label="Confirmar nova senha">
              <input
                type="password"
                value={confirmar}
                onChange={(e) => setConfirmar(e.target.value)}
                className={campoClass}
              />
            </Campo>
            <Button type="submit" loading={carregando} className="w-full mt-1">
              {carregando ? "Salvando…" : "Redefinir senha"}
            </Button>
          </form>
        )
      )}

      <p className="text-center text-[13px] text-muted mt-6">
        <Link href="/login" className="text-g800 font-semibold">
          ← Voltar para o login
        </Link>
      </p>
    </AuthShell>
  );
}

export default function RedefinirSenhaPage() {
  return (
    <Suspense fallback={null}>
      <RedefinirSenhaForm />
    </Suspense>
  );
}
