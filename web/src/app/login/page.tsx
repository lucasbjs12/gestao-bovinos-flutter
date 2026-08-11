"use client";

import { useState, FormEvent } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { AlertCircle } from "lucide-react";
import { backendAuth } from "@/lib/backend-auth";
import { ApiException } from "@/lib/api-exception";
import { useAuth } from "@/lib/auth-context";
import { AuthShell, AuthBrand, Campo, campoClass } from "@/components/AuthCard";
import { Button } from "@/components/ui/Button";

function traduzirErro(err: unknown): string {
  if (err instanceof ApiException) {
    if (err.statusCode === 401) return "E-mail ou senha inválidos.";
    return err.message || "Erro ao entrar. Tente novamente.";
  }
  return "Sem conexão com o servidor.";
}

export default function LoginPage() {
  const router = useRouter();
  const { recarregar } = useAuth();
  const [email, setEmail] = useState("");
  const [senha, setSenha] = useState("");
  const [carregando, setCarregando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  async function entrar(e: FormEvent) {
    e.preventDefault();
    if (!email || !senha) {
      setErro("Preencha e-mail e senha.");
      return;
    }
    setErro(null);
    setCarregando(true);
    try {
      await backendAuth.login(email.trim(), senha);
      await recarregar();
      router.push("/inicio");
    } catch (err) {
      setErro(traduzirErro(err));
    } finally {
      setCarregando(false);
    }
  }

  return (
    <AuthShell>
      <AuthBrand />

      <h1 className="font-display text-2xl font-semibold text-text text-center mb-1.5">
        Bem-vindo de volta
      </h1>
      <p className="text-sm text-muted text-center mb-8">
        Use as mesmas credenciais do aplicativo
      </p>

      {erro && (
        <div className="flex items-start gap-2 bg-danger-bg rounded-xl px-3.5 py-2.5 text-sm text-danger mb-4">
          <AlertCircle size={16} className="shrink-0 mt-0.5" />
          {erro}
        </div>
      )}

      <form onSubmit={entrar} className="flex flex-col gap-4">
        <Campo label="E-mail">
          <input
            id="email"
            type="email"
            autoComplete="email"
            placeholder="seu@email.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className={campoClass}
          />
        </Campo>
        <Campo label="Senha">
          <input
            id="senha"
            type="password"
            autoComplete="current-password"
            placeholder="••••••••"
            value={senha}
            onChange={(e) => setSenha(e.target.value)}
            className={campoClass}
          />
          <div className="text-right">
            <Link href="/esqueci-senha" className="text-xs text-muted hover:text-g800">
              Esqueci minha senha
            </Link>
          </div>
        </Campo>

        <Button type="submit" loading={carregando} className="w-full mt-1" size="md">
          {carregando ? "Entrando…" : "Entrar no painel"}
        </Button>
      </form>

      <hr className="border-border-soft my-6" />
      <p className="text-center text-[13px] text-muted">
        Não tem conta?{" "}
        <Link href="/escolha-cadastro" className="text-g800 font-semibold">
          Cadastre-se
        </Link>
      </p>
    </AuthShell>
  );
}
