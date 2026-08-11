"use client";

import { useEffect, useState } from "react";
import { UserPlus, Crown, User, Trash2, Copy, Check, Users, MessageCircle } from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { membrosApi, Membro } from "@/lib/api/membros";
import { convitesApi } from "@/lib/api/convites";
import { PageHeader } from "@/components/ui/PageHeader";
import { Card, CardHeader } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { EmptyState, Spinner } from "@/components/ui/EmptyState";

export default function MembrosPage() {
  const { fazendaId, souDono, user } = useAuth();
  const [membros, setMembros] = useState<Membro[] | null>(null);
  const [codigo, setCodigo] = useState<string | null>(null);
  const [gerando, setGerando] = useState(false);
  const [copiado, setCopiado] = useState(false);

  async function carregar() {
    if (!fazendaId) return;
    setMembros(await membrosApi.listar(fazendaId));
  }

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    carregar();
  }, [fazendaId]);

  async function gerar() {
    if (!fazendaId) return;
    setGerando(true);
    try {
      const convite = await convitesApi.gerar(fazendaId);
      setCodigo(convite.codigo);
      setCopiado(false);
    } finally {
      setGerando(false);
    }
  }

  async function copiar() {
    if (!codigo) return;
    await navigator.clipboard.writeText(codigo);
    setCopiado(true);
    setTimeout(() => setCopiado(false), 2000);
  }

  function compartilharWhatsapp() {
    if (!codigo) return;
    const nome = user?.displayName || "minha fazenda";
    const mensagem =
      `Você foi convidado para ajudar em ${nome} no Gestão de Rebanho! ` +
      `Acesse o app ou o site, cadastre-se como convidado e use o código: ${codigo} ` +
      `(válido por 48h).`;
    window.open(`https://wa.me/?text=${encodeURIComponent(mensagem)}`, "_blank");
  }

  async function remover(usuarioId: string, nome?: string | null) {
    if (!fazendaId) return;
    if (!confirm(`Remover ${nome ?? "este membro"} da fazenda?`)) return;
    await membrosApi.remover(fazendaId, usuarioId);
    carregar();
  }

  if (!souDono) {
    return (
      <p className="text-sm text-muted">
        Só o dono da fazenda pode gerenciar membros.
      </p>
    );
  }

  return (
    <div className="max-w-lg">
      <PageHeader title="Membros da fazenda" />

      <Card className="p-6 mb-5">
        <p className="text-sm text-muted mb-4">
          Gere um código para convidar alguém a ajudar na fazenda. O código
          vale por 48 horas e só pode ser usado uma vez.
        </p>
        <Button onClick={gerar} loading={gerando} icon={<UserPlus size={15} />}>
          {gerando ? "Gerando…" : "Gerar código de convite"}
        </Button>
        {codigo && (
          <>
            <button
              onClick={copiar}
              className="mt-4 w-full flex items-center justify-between gap-3 bg-cream border border-border rounded-xl px-4 py-3 hover:border-g600 transition-colors group"
            >
              <div className="text-left">
                <span className="text-lg font-bold tracking-widest font-mono text-text">
                  {codigo}
                </span>
                <span className="block text-xs text-muted">válido por 48h</span>
              </div>
              {copiado ? (
                <Check size={16} className="text-g700 shrink-0" />
              ) : (
                <Copy size={16} className="text-muted-2 group-hover:text-g700 shrink-0" />
              )}
            </button>
            <Button
              onClick={compartilharWhatsapp}
              variant="secondary"
              icon={<MessageCircle size={15} />}
              className="w-full mt-3"
            >
              Compartilhar no WhatsApp
            </Button>
          </>
        )}
      </Card>

      <Card className="overflow-hidden">
        <CardHeader title="Equipe" />
        {membros === null && <Spinner />}
        {membros !== null && membros.length === 0 && (
          <EmptyState
            icon={<Users size={20} />}
            title="Nenhum membro convidado ainda"
            description="Compartilhe o código gerado acima."
          />
        )}
        <div className="divide-y divide-border-soft">
          {membros?.map((m) => (
            <div
              key={m.usuarioId}
              className="flex items-center justify-between px-5 py-3.5"
            >
              <div className="flex items-center gap-3">
                <div
                  className={`w-8 h-8 rounded-full flex items-center justify-center shrink-0 ${
                    m.papel === "dono" ? "bg-gold-50 text-[#8a6516]" : "bg-g50 text-g800"
                  }`}
                >
                  {m.papel === "dono" ? <Crown size={14} /> : <User size={14} />}
                </div>
                <div>
                  <div className="text-sm font-semibold text-text">{m.nome || m.usuarioId}</div>
                  <div className="text-xs text-muted capitalize">{m.papel}</div>
                </div>
              </div>
              {m.papel !== "dono" && (
                <button
                  onClick={() => remover(m.usuarioId, m.nome)}
                  className="p-1.5 rounded-md text-muted-2 hover:text-danger hover:bg-danger-bg transition-colors"
                  aria-label="Remover"
                >
                  <Trash2 size={14} />
                </button>
              )}
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
}
