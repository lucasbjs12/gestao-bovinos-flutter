"use client";

import Link from "next/link";
import { ScrollText, Users, ArrowLeftRight, ShieldCheck, ExternalLink, ChevronRight, SlidersHorizontal, ShieldAlert, Crown } from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { PageHeader } from "@/components/ui/PageHeader";
import { Card } from "@/components/ui/Card";
import { Badge } from "@/components/ui/Badge";

export default function PerfilPage() {
  const { user, souDono, ehConvidado, fazendaId, isAdmin } = useAuth();

  return (
    <div className="max-w-lg">
      <PageHeader title="Perfil" />

      <Card className="p-6 mb-4">
        <div className="flex items-center gap-3.5 mb-4">
          <div className="w-[52px] h-[52px] rounded-full bg-g50 flex items-center justify-center text-lg font-bold text-g800 shrink-0">
            {user?.email?.[0]?.toUpperCase() ?? "?"}
          </div>
          <div className="min-w-0">
            <div className="text-[15px] font-bold text-text truncate">
              {user?.displayName || "Sem nome"}
            </div>
            <div className="text-xs text-muted truncate">{user?.email}</div>
          </div>
        </div>
        <div className="flex gap-2">
          <Badge tone="green">{souDono ? "Dono" : "Membro"}</Badge>
        </div>
      </Card>

      <Card className="divide-y divide-border-soft overflow-hidden mb-4">
        <PerfilItem href="/diario" icon={<ScrollText size={17} />} label="Diário de atividades" />
        {souDono && (
          <PerfilItem href="/membros" icon={<Users size={17} />} label="Membros da fazenda" />
        )}
        {ehConvidado && (
          <PerfilItem href="/entrar-fazenda" icon={<ArrowLeftRight size={17} />} label="Trocar de fazenda" />
        )}
        <PerfilItem
          href="/perfil/personalizar-cadastro"
          icon={<SlidersHorizontal size={17} />}
          label="Personalizar cadastro"
        />
        {souDono && (
          <PerfilItem href="/planos" icon={<Crown size={17} />} label="Planos e assinatura" />
        )}
        {isAdmin && (
          <PerfilItem
            href="/admin"
            icon={<ShieldAlert size={17} />}
            label="Painel admin"
          />
        )}
        <a
          href="https://www.gestaobovinos.com.br/#privacy"
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center gap-3 px-5 py-4 hover:bg-cream transition-colors"
        >
          <ShieldCheck size={17} className="text-muted-2" />
          <span className="text-sm font-medium text-text flex-1">Política de privacidade</span>
          <ExternalLink size={14} className="text-muted-2" />
        </a>
      </Card>

      <p className="text-xs text-muted px-1">
        Fazenda ativa: <span className="font-mono">{fazendaId}</span>
      </p>
    </div>
  );
}

function PerfilItem({
  href,
  icon,
  label,
}: {
  href: string;
  icon: React.ReactNode;
  label: string;
}) {
  return (
    <Link href={href} className="flex items-center gap-3 px-5 py-4 hover:bg-cream transition-colors">
      <span className="text-muted-2">{icon}</span>
      <span className="text-sm font-medium text-text flex-1">{label}</span>
      <ChevronRight size={16} className="text-muted-2" />
    </Link>
  );
}
