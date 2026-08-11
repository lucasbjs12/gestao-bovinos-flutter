"use client";

import { useState, FormEvent } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { AlertCircle } from "lucide-react";
import { AuthShell, AuthBrand, Campo, campoClass } from "@/components/AuthCard";
import { Button } from "@/components/ui/Button";
import { backendAuth } from "@/lib/backend-auth";
import { ApiException } from "@/lib/api-exception";
import { useAuth } from "@/lib/auth-context";

export default function CadastroFazendaPage() {
  const router = useRouter();
  const { recarregar } = useAuth();
  const [seuNome, setSeuNome] = useState("");
  const [nome, setNome] = useState("");
  const [email, setEmail] = useState("");
  const [senha, setSenha] = useState("");
  const [confirmar, setConfirmar] = useState("");
  const [carregando, setCarregando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  async function criarConta(e: FormEvent) {
    e.preventDefault();
    if (!seuNome.trim() || seuNome.trim().length < 2)
      return setErro("Informe o seu nome (mínimo 2 caracteres).");
    if (!nome.trim()) return setErro("Informe o nome da fazenda.");
    if (senha.length < 8)
      return setErro("A senha deve ter pelo menos 8 caracteres.");
    if (senha !== confirmar) return setErro("As senhas não coincidem.");

    setErro(null);
    setCarregando(true);
    try {
      await backendAuth.registrar(seuNome.trim(), email.trim(), senha, nome.trim());
      await recarregar();
      router.push("/inicio");
    } catch (err) {
      setErro(err instanceof ApiException ? err.message : "Erro ao criar conta. Tente novamente.");
    } finally {
      setCarregando(false);
    }
  }

  return (
    <AuthShell>
      <AuthBrand />
      <h1 className="font-display text-2xl font-semibold text-text text-center mb-1.5">
        Criar conta de produtor
      </h1>
      <p className="text-sm text-muted text-center mb-7">
        Comece a gerenciar seu rebanho pelo navegador
      </p>

      {erro && (
        <div className="flex items-start gap-2 bg-danger-bg rounded-xl px-3.5 py-2.5 text-sm text-danger mb-4">
          <AlertCircle size={16} className="shrink-0 mt-0.5" />
          {erro}
        </div>
      )}

      <form onSubmit={criarConta} className="flex flex-col gap-4">
        <Campo label="Seu nome">
          <input
            value={seuNome}
            onChange={(e) => setSeuNome(e.target.value)}
            className={campoClass}
          />
        </Campo>
        <Campo label="Nome da fazenda">
          <input
            value={nome}
            onChange={(e) => setNome(e.target.value)}
            className={campoClass}
          />
        </Campo>
        <Campo label="E-mail">
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className={campoClass}
          />
        </Campo>
        <Campo label="Senha">
          <input
            type="password"
            value={senha}
            onChange={(e) => setSenha(e.target.value)}
            className={campoClass}
          />
        </Campo>
        <Campo label="Confirmar senha">
          <input
            type="password"
            value={confirmar}
            onChange={(e) => setConfirmar(e.target.value)}
            className={campoClass}
          />
        </Campo>

        <Button type="submit" loading={carregando} className="w-full mt-1">
          {carregando ? "Criando…" : "Criar minha conta"}
        </Button>
      </form>

      <p className="text-center text-[13px] text-muted mt-6">
        <Link href="/escolha-cadastro" className="text-g800 font-semibold">
          ← Voltar
        </Link>
      </p>
    </AuthShell>
  );
}
