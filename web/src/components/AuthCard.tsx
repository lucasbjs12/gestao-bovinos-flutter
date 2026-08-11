"use client";

import { ReactNode } from "react";
import { BrandMark } from "./ui/BrandMark";

export function AuthShell({ children }: { children: ReactNode }) {
  return (
    <main className="min-h-screen flex items-center justify-center p-6 relative overflow-hidden bg-forest">
      <div
        className="absolute inset-0 pointer-events-none"
        style={{
          background:
            "radial-gradient(ellipse 60% 50% at 15% 15%, rgba(76,175,80,.22), transparent 60%), radial-gradient(ellipse 55% 55% at 85% 85%, rgba(200,168,75,.14), transparent 60%), linear-gradient(160deg, #050e07 0%, #0b2410 55%, #123018 100%)",
        }}
      />
      <div
        className="absolute inset-0 pointer-events-none opacity-[0.05]"
        style={{
          backgroundImage:
            "radial-gradient(rgba(255,255,255,.6) 1px, transparent 1px)",
          backgroundSize: "28px 28px",
        }}
      />
      <div className="relative z-10 w-full max-w-[440px] bg-surface rounded-[26px] p-9 shadow-lg border border-white/5">
        {children}
      </div>
    </main>
  );
}

export function AuthBrand() {
  return (
    <div className="flex items-center gap-3 justify-center mb-7">
      <BrandMark size={42} />
      <div className="text-left">
        <div className="font-display text-[16px] font-semibold text-text leading-tight">
          Gestão de Rebanho
        </div>
        <div className="text-[11px] text-muted uppercase tracking-wide">
          Painel do Cliente
        </div>
      </div>
    </div>
  );
}

export function Campo({
  label,
  children,
}: {
  label: string;
  children: ReactNode;
}) {
  return (
    <label className="flex flex-col gap-1.5">
      <span className="text-xs font-semibold text-text">{label}</span>
      {children}
    </label>
  );
}

export const campoClass = "field";
