"use client";

import { useState, FormEvent } from "react";
import { useRouter } from "next/navigation";
import { IdCard, CheckCircle2, AlertCircle, Users } from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { convitesApi } from "@/lib/api/convites";
import { ApiException } from "@/lib/api-exception";
import { AuthShell } from "@/components/AuthCard";
import { Button } from "@/components/ui/Button";

export default function EntrarFazendaPage() {
  const { user, fazendaId, entrarNaFazenda, fazendasVinculadas, logout } =
    useAuth();
  const router = useRouter();
  const [codigo, setCodigo] = useState("");
  const [processando, setProcessando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const [mostrarCodigo, setMostrarCodigo] = useState(false);

  const vinculos = fazendasVinculadas();

  function trocarPara(id: string, nome?: string) {
    entrarNaFazenda(id, nome);
    router.push("/inicio");
  }

  async function entrar(e: FormEvent) {
    e.preventDefault();
    if (!codigo.trim()) return;
    setErro(null);
    setProcessando(true);
    try {
      const r = await convitesApi.aceitar(codigo);
      entrarNaFazenda(r.fazenda.id, r.fazenda.nome);
      router.push("/inicio");
    } catch (err) {
      setErro(err instanceof ApiException ? err.message : "Erro ao entrar na fazenda.");
    } finally {
      setProcessando(false);
    }
  }

  return (
    <AuthShell>
      <div className="w-14 h-14 rounded-2xl bg-gold-50 flex items-center justify-center text-[#8a6516] mb-6">
        <IdCard size={26} />
      </div>
      <h1 className="font-display text-2xl font-semibold text-text mb-2">
        {vinculos.length > 0
          ? "Trocar de fazenda"
          : user?.displayName
          ? `Olá, ${user.displayName}`
          : "Bem-vindo!"}
      </h1>
      <p className="text-sm text-muted mb-6 leading-relaxed">
        {vinculos.length > 0
          ? "Escolha uma fazenda ou entre em uma nova com um código de convite."
          : "Você entrou como convidado. Digite o código de convite que o dono da fazenda compartilhou com você."}
      </p>

      {vinculos.length > 0 && (
        <div className="flex flex-col gap-2 mb-5">
          {vinculos.map((v) => (
            <button
              key={v.id}
              onClick={() => trocarPara(v.id, v.nome)}
              disabled={v.id === fazendaId}
              className={`flex items-center gap-3 text-left px-4 py-3 rounded-xl border text-sm transition-colors ${
                v.id === fazendaId
                  ? "border-g600 bg-g50 font-semibold"
                  : "border-border hover:bg-cream"
              }`}
            >
              {v.id === fazendaId ? (
                <CheckCircle2 size={18} className="text-g700 shrink-0" />
              ) : (
                <Users size={18} className="text-muted-2 shrink-0" />
              )}
              <span>
                {v.nome || "Fazenda compartilhada"}
                <span className="block text-xs text-muted font-normal">
                  Compartilhada · convidado
                </span>
              </span>
            </button>
          ))}
        </div>
      )}

      {erro && (
        <div className="flex items-start gap-2 bg-danger-bg rounded-xl px-3.5 py-2.5 text-sm text-danger mb-4">
          <AlertCircle size={16} className="shrink-0 mt-0.5" />
          {erro}
        </div>
      )}

      {!mostrarCodigo && vinculos.length > 0 ? (
        <Button
          onClick={() => setMostrarCodigo(true)}
          variant="secondary"
          className="w-full"
        >
          Entrar em outra fazenda
        </Button>
      ) : (
        <form onSubmit={entrar} className="flex flex-col gap-4">
          <input
            value={codigo}
            onChange={(e) => setCodigo(e.target.value.toUpperCase())}
            placeholder="BOV-XXXXXX"
            className="w-full px-4 py-4 border-[1.5px] border-border rounded-xl text-center text-xl font-bold tracking-widest outline-none focus:border-gold focus:ring-2 focus:ring-gold/20 bg-cream"
          />
          <Button type="submit" loading={processando} variant="gold" className="w-full">
            {processando ? "Entrando…" : "Acessar a fazenda"}
          </Button>
        </form>
      )}

      <button
        type="button"
        onClick={() => {
          logout();
          router.replace("/login");
        }}
        className="text-xs text-muted hover:text-text mt-5"
      >
        Sair
      </button>
    </AuthShell>
  );
}
