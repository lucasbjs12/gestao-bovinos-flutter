"use client";

import Link from "next/link";
import { ChevronRight, Home, HandHeart } from "lucide-react";
import { AuthShell, AuthBrand } from "@/components/AuthCard";

export default function EscolhaCadastroPage() {
  return (
    <AuthShell>
      <AuthBrand />
      <h1 className="font-display text-2xl font-semibold text-text text-center mb-1.5">
        Como você vai usar o painel?
      </h1>
      <p className="text-sm text-muted text-center mb-8">
        Escolha o tipo de conta para continuar
      </p>

      <div className="flex flex-col gap-3">
        <Link
          href="/cadastro-fazenda"
          className="group flex items-center gap-4 border-[1.5px] border-border rounded-2xl p-5 hover:border-g600 hover:bg-g50 transition-colors"
        >
          <div className="w-11 h-11 rounded-xl bg-g50 group-hover:bg-white flex items-center justify-center text-g800 shrink-0">
            <Home size={20} />
          </div>
          <div className="flex-1">
            <div className="text-[15px] font-bold text-text mb-0.5">
              Sou produtor
            </div>
            <div className="text-[13px] text-muted">
              Tenho uma fazenda e quero gerenciar meu rebanho.
            </div>
          </div>
          <ChevronRight size={18} className="text-muted-2 group-hover:text-g700 shrink-0" />
        </Link>

        <Link
          href="/cadastro-convidado"
          className="group flex items-center gap-4 border-[1.5px] border-border rounded-2xl p-5 hover:border-gold hover:bg-gold-50 transition-colors"
        >
          <div className="w-11 h-11 rounded-xl bg-gold-50 group-hover:bg-white flex items-center justify-center text-[#8a6516] shrink-0">
            <HandHeart size={20} />
          </div>
          <div className="flex-1">
            <div className="text-[15px] font-bold text-text mb-0.5">
              Sou convidado
            </div>
            <div className="text-[13px] text-muted">
              Vou ajudar na fazenda de um produtor com um código de convite.
            </div>
          </div>
          <ChevronRight size={18} className="text-muted-2 group-hover:text-[#8a6516] shrink-0" />
        </Link>
      </div>

      <p className="text-center text-[13px] text-muted mt-7">
        Já tem conta?{" "}
        <Link href="/login" className="text-g800 font-semibold">
          Entrar
        </Link>
      </p>
    </AuthShell>
  );
}
