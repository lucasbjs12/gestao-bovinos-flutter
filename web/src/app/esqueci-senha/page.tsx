"use client";

import { useState, FormEvent } from "react";
import Link from "next/link";
import { CheckCircle2, MailQuestion } from "lucide-react";
import { backendAuth } from "@/lib/backend-auth";
import { AuthShell, AuthBrand, Campo, campoClass } from "@/components/AuthCard";
import { Button } from "@/components/ui/Button";

export default function EsqueciSenhaPage() {
  const [email, setEmail] = useState("");
  const [carregando, setCarregando] = useState(false);
  const [enviado, setEnviado] = useState(false);

  async function enviar(e: FormEvent) {
    e.preventDefault();
    if (!email.trim()) return;
    setCarregando(true);
    try {
      await backendAuth.esqueciSenha(email.trim());
    } finally {
      // Sempre mostra a mesma mensagem de sucesso, exista ou não o e-mail
      // (o backend também não revela isso) -- evita confirmar contas existentes.
      setCarregando(false);
      setEnviado(true);
    }
  }

  return (
    <AuthShell>
      <AuthBrand />
      <div className="w-14 h-14 rounded-2xl bg-g50 flex items-center justify-center text-g800 mx-auto mb-6">
        <MailQuestion size={26} />
      </div>
      <h1 className="font-display text-2xl font-semibold text-text text-center mb-1.5">
        Esqueci minha senha
      </h1>
      <p className="text-sm text-muted text-center mb-7">
        Digite seu e-mail e enviaremos um link pra você escolher uma nova senha.
      </p>

      {enviado ? (
        <div className="flex items-start gap-2 bg-g50 rounded-xl px-3.5 py-3 text-sm text-g800">
          <CheckCircle2 size={16} className="shrink-0 mt-0.5" />
          Se esse e-mail tiver uma conta, você vai receber um link de
          redefinição em instantes. Confira também a caixa de spam.
        </div>
      ) : (
        <form onSubmit={enviar} className="flex flex-col gap-4">
          <Campo label="E-mail">
            <input
              type="email"
              autoComplete="email"
              placeholder="seu@email.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className={campoClass}
            />
          </Campo>
          <Button type="submit" loading={carregando} className="w-full mt-1">
            {carregando ? "Enviando…" : "Enviar link de redefinição"}
          </Button>
        </form>
      )}

      <p className="text-center text-[13px] text-muted mt-6">
        <Link href="/login" className="text-g800 font-semibold">
          ← Voltar para o login
        </Link>
      </p>
    </AuthShell>
  );
}
