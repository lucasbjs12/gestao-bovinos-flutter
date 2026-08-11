"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { useAuth } from "@/lib/auth-context";
import "./telas.css";

const MARCA_URL =
  "https://raw.githubusercontent.com/lucasbjs12/gestao-bovinos-flutter/master/assets/images/marca.png";

const TELAS = [
  {
    src: "/screenshots/tela-inicio.jpeg",
    alt: "Tela inicial do app",
    titulo: "Painel inicial",
    desc: "Resumo completo do rebanho assim que você abre o app — total de animais, distribuição por categoria e acesso rápido a todas as funções.",
  },
  {
    src: "/screenshots/tela-bovinos.jpeg",
    alt: "Lista de bovinos",
    titulo: "Lista de animais",
    desc: "Filtre por categoria, busque pelo brinco ou nome e identifique rapidamente quais animais estão sem peso ou sem manejo registrado.",
  },
  {
    src: "/screenshots/tela-detalhe.jpeg",
    alt: "Detalhe do bovino",
    titulo: "Ficha do animal",
    desc: "Acesse raça, peso, nascimento, invernada e histórico sanitário de cada animal. Tudo em um único lugar, disponível offline.",
  },
  {
    src: "/screenshots/tela-invernada.jpeg",
    alt: "Detalhe da invernada",
    titulo: "Controle de invernadas",
    desc: "Veja quais animais estão em cada pasto, peso total do lote, área em hectares e lotação atual — para decisões mais precisas de manejo.",
  },
  {
    src: "/screenshots/tela-evento.jpeg",
    alt: "Registro de evento sanitário",
    titulo: "Manejos sanitários",
    desc: "Registre vacinações, vermifugações e outros manejos com produto, dosagem e responsável. Associe a um ou vários animais de uma vez.",
  },
  {
    src: "/screenshots/tela-lote.jpeg",
    alt: "Cadastro em lote",
    titulo: "Cadastro em lote",
    desc: "Na hora da entrada de animais, cadastre vários de uma vez. Brinco, categoria, peso e data de nascimento — rápido e sem erros.",
  },
];

export default function TelasContent() {
  const { user } = useAuth();
  const painelHref = user ? "/inicio" : "/login";

  const [navSolid, setNavSolid] = useState(false);
  const revealRefs = useRef<Array<HTMLElement | null>>([]);

  useEffect(() => {
    const onScroll = () => setNavSolid(window.scrollY > 70);
    addEventListener("scroll", onScroll, { passive: true });
    return () => removeEventListener("scroll", onScroll);
  }, []);

  useEffect(() => {
    const obs = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("in");
            obs.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.12 },
    );
    revealRefs.current.forEach((el) => el && obs.observe(el));
    return () => obs.disconnect();
  }, []);

  const addReveal = (el: HTMLElement | null) => {
    if (el && !revealRefs.current.includes(el)) revealRefs.current.push(el);
  };

  return (
    <div className="telas">
      <nav className={`nav${navSolid ? " solid" : ""}`}>
        <Link href="/" className="nav-logo">
          <img src={MARCA_URL} alt="GR" />
          <span className="nav-logo-name">Gestão de Rebanho</span>
        </Link>
        <div className="nav-links">
          <Link href="/#features">Funcionalidades</Link>
          <Link href="/#how">Como funciona</Link>
          <Link href="/#privacy">Privacidade</Link>
          <Link href={painelHref} className="nav-cta">Acessar Painel</Link>
        </div>
      </nav>

      <section className="page-hero">
        <div className="hero-grid" />
        <div className="page-hero-inner">
          <div className="ph-pill r in"><span /> Telas reais do aplicativo</div>
          <h1 className="r in" style={{ transitionDelay: ".08s" }}>
            O app na sua <em>rotina diária</em>
          </h1>
          <p className="r in" style={{ transitionDelay: ".16s" }}>
            Do cadastro ao manejo sanitário — veja como o Gestão de Rebanho acompanha cada etapa do seu trabalho no
            campo.
          </p>
        </div>
      </section>

      <section className="screens-sec">
        <div className="screens-sec-inner">
          <div className="screens-grid">
            {TELAS.map((tela, i) => (
              <div className="sc-card r" ref={addReveal} key={tela.src} style={{ transitionDelay: `${i * 0.08}s` }}>
                <div className="phone-frame">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img className="phone-screen" src={tela.src} alt={tela.alt} />
                </div>
                <div className="sc-info">
                  <div className="sc-num">{i + 1}</div>
                  <div className="sc-title">{tela.titulo}</div>
                  <div className="sc-desc">{tela.desc}</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="app-cta">
        <div className="app-cta-in">
          <h2 className="r in">Pronto para começar?</h2>
          <p className="r in" style={{ transitionDelay: ".1s" }}>
            Baixe o app e tenha o controle do seu rebanho na palma da mão — funciona mesmo sem internet.
          </p>
          <div className="cta-btns r in" style={{ transitionDelay: ".2s" }}>
            <Link href="/" className="btn-primary">
              <svg width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
                <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z" />
              </svg>
              Conhecer o app
            </Link>
            <Link href={painelHref} className="btn-ghost">
              Acessar painel web →
            </Link>
          </div>
        </div>
      </section>

      <footer className="telas-footer">
        <div className="ft-in">
          <div className="ft-top">
            <div>
              <div className="ft-brand">
                <img src={MARCA_URL} alt="GR" />
                <span className="ft-brand-n">Gestão de Rebanho</span>
              </div>
              <p className="ft-tag">
                Aplicativo de gestão pecuária desenvolvido para o produtor rural brasileiro. Simples, rápido e seguro
                — mesmo sem internet.
              </p>
            </div>
            <div>
              <div className="ft-col-h">Navegação</div>
              <ul className="ft-links">
                <li><Link href="/#features">Funcionalidades</Link></li>
                <li><Link href="/#how">Como funciona</Link></li>
                <li><Link href="/app">App no dia a dia</Link></li>
                <li><Link href={painelHref}>Painel Web</Link></li>
              </ul>
            </div>
            <div>
              <div className="ft-col-h">Legal</div>
              <ul className="ft-links">
                <li><Link href="/#privacy">Política de Privacidade</Link></li>
                <li><Link href="/#privacy">Termos de Uso</Link></li>
                <li><Link href="/#privacy">LGPD</Link></li>
              </ul>
            </div>
          </div>
          <div className="ft-bot">
            <span>© 2026 Gestão de Rebanho. Todos os direitos reservados.</span>
            <span className="lgpd">🛡️ Conformidade LGPD</span>
          </div>
        </div>
      </footer>
    </div>
  );
}
