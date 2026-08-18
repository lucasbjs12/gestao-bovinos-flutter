"use client";

import { ReactNode, useEffect } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import {
  LayoutDashboard,
  Beef,
  Sprout,
  Syringe,
  CircleUserRound,
  LogOut,
  Crown,
  Users,
  Nfc,
} from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { BrandMark } from "@/components/ui/BrandMark";
import { Onboarding } from "@/components/Onboarding";

const NAV = [
  { href: "/inicio", label: "Início", icon: LayoutDashboard },
  { href: "/bovinos", label: "Bovinos", icon: Beef },
  { href: "/invernadas", label: "Invernadas", icon: Sprout },
  { href: "/eventos", label: "Sanidade", icon: Syringe },
  { href: "/rfid", label: "RFID", icon: Nfc },
];

const NAV_SIDEBAR = [
  ...NAV,
  { href: "/planos", label: "Planos e Assinatura", icon: Crown },
  { href: "/perfil", label: "Perfil", icon: CircleUserRound },
];

export default function PainelLayout({ children }: { children: ReactNode }) {
  const { user, loading, logout, souDono, ehConvidado } = useAuth();
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    if (loading) return;
    if (!user) {
      router.replace("/login");
    }
  }, [loading, user, router]);

  if (loading || !user) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center bg-cream gap-3">
        <BrandMark size={36} />
        <span className="w-4 h-4 rounded-full border-2 border-border border-t-g700 spin" />
      </div>
    );
  }

  function ativo(href: string) {
    return pathname === href || (pathname?.startsWith(href + "/") && href !== "/perfil");
  }

  return (
    <div className="min-h-screen bg-cream">
      {!ehConvidado && <Onboarding />}

      {/* Topo mobile — some em telas grandes, onde a sidebar assume */}
      <header className="lg:hidden sticky top-0 z-20 flex items-center justify-between gap-3 px-4 py-3 bg-forest">
        <div className="flex items-center gap-2.5 min-w-0">
          <BrandMark size={30} />
          <span className="font-display text-[13px] font-semibold text-white truncate">
            Gestão de Rebanho
          </span>
        </div>
        <Link
          href="/perfil"
          className={`w-8 h-8 rounded-full flex items-center justify-center shrink-0 ${
            ativo("/perfil") ? "bg-white/20" : "bg-white/10"
          }`}
          aria-label="Perfil"
        >
          <CircleUserRound size={17} className="text-white" />
        </Link>
      </header>

      {/* Sidebar — só em telas grandes (lg: 1024px+) */}
      <aside className="hidden lg:flex w-64 shrink-0 min-h-screen fixed left-0 top-0 flex-col bg-gradient-to-b from-[#0a1f0d] to-g800">
        <div className="flex items-center gap-2.5 px-5 py-5">
          <BrandMark size={34} />
          <div>
            <div className="font-display text-[13.5px] font-semibold text-white leading-tight">
              Gestão de Rebanho
            </div>
            <div className="text-[10px] text-white/40 uppercase tracking-wider">
              Painel
            </div>
          </div>
        </div>

        <div className="mx-5 mb-2 flex items-center gap-2 px-3 py-2 rounded-lg bg-white/5">
          {souDono ? (
            <Crown size={13} className="text-gold-lt shrink-0" />
          ) : (
            <Users size={13} className="text-white/50 shrink-0" />
          )}
          <span className="text-[11px] font-semibold text-white/70 truncate">
            {souDono ? "Você é o dono" : "Membro convidado"}
          </span>
        </div>

        <nav className="flex-1 py-3 flex flex-col gap-0.5 px-3">
          {NAV_SIDEBAR.map((item) => {
            const Icon = item.icon;
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`flex items-center gap-3 px-3 py-2.5 rounded-[10px] text-[13.5px] transition-colors ${
                  ativo(item.href)
                    ? "bg-white/[0.08] text-white font-semibold"
                    : "text-white/55 hover:bg-white/[0.05] hover:text-white"
                }`}
              >
                <Icon size={17} strokeWidth={ativo(item.href) ? 2.3 : 2} />
                {item.label}
              </Link>
            );
          })}
        </nav>

        <div className="px-4 py-4 border-t border-white/[0.08]">
          <div className="flex items-center gap-2.5 mb-3 px-1">
            <div className="w-8 h-8 rounded-full bg-white/10 flex items-center justify-center text-xs font-bold text-white shrink-0">
              {user.email?.[0]?.toUpperCase() ?? "?"}
            </div>
            <div className="min-w-0">
              <div className="text-xs font-medium text-white/85 truncate">
                {user.displayName || user.email}
              </div>
              {user.displayName && (
                <div className="text-[10.5px] text-white/40 truncate">
                  {user.email}
                </div>
              )}
            </div>
          </div>
          <button
            onClick={() => {
              logout();
              router.replace("/login");
            }}
            className="w-full flex items-center justify-center gap-2 py-2 rounded-lg border border-white/10 text-white/55 text-[12.5px] font-medium hover:bg-red-500/10 hover:border-red-400/25 hover:text-red-300 transition-colors"
          >
            <LogOut size={13} />
            Sair
          </button>
        </div>
      </aside>

      <main className="lg:ml-64 px-4 py-5 sm:px-6 lg:px-8 lg:py-8 max-w-[1400px] min-w-0 pb-24 lg:pb-8">
        {children}
      </main>

      {/* Navegação inferior — só em telas pequenas, igual à bottom nav do app */}
      <nav className="lg:hidden fixed bottom-0 left-0 right-0 z-20 flex items-stretch bg-surface border-t border-border">
        {NAV.map((item) => {
          const Icon = item.icon;
          const on = ativo(item.href);
          return (
            <Link
              key={item.href}
              href={item.href}
              className="flex-1 flex flex-col items-center justify-center gap-1 py-2.5"
            >
              <Icon
                size={20}
                strokeWidth={on ? 2.4 : 1.8}
                className={on ? "text-g800" : "text-muted-2"}
              />
              <span className={`text-[10px] ${on ? "text-g800 font-semibold" : "text-muted-2"}`}>
                {item.label}
              </span>
            </Link>
          );
        })}
      </nav>
    </div>
  );
}
