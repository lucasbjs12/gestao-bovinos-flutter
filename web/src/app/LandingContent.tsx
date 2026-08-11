"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { useAuth } from "@/lib/auth-context";
import "./landing.css";

const MARCA_URL =
  "https://raw.githubusercontent.com/lucasbjs12/gestao-bovinos-flutter/master/assets/images/marca.png";

const CYCLE_WORDS = ["controle", "segurança", "praticidade", "eficiência", "tranquilidade"];

const FAQ = [
  {
    pergunta: "Que dados são coletados?",
    resposta:
      "Coletamos apenas o necessário para o funcionamento do aplicativo: e-mail para autenticação e os dados pecuários que você mesmo cadastra (bovinos, invernadas, eventos). Nenhuma informação sensível pessoal além do e-mail de login.",
  },
  {
    pergunta: "Os dados ficam no celular ou na nuvem?",
    resposta:
      "Os dados ficam armazenados localmente no seu dispositivo (SQLite) e são sincronizados com o backend na nuvem quando há conexão com a internet. Isso garante que o app funcione 100% offline sem perda de dados.",
  },
  {
    pergunta: "Posso excluir meus dados?",
    resposta:
      "Sim. Você pode excluir sua conta e todos os dados associados a qualquer momento, diretamente pelo aplicativo ou pelo site, na tela de perfil.",
  },
  {
    pergunta: "O app acessa câmera e armazenamento do celular?",
    resposta:
      "Sim, mas somente quando você inicia uma ação manualmente (como tirar uma foto de um animal). Nenhum acesso acontece em segundo plano. As permissões são solicitadas de forma transparente.",
  },
  {
    pergunta: "Onde os dados ficam hospedados?",
    resposta:
      "Os dados são armazenados em um banco PostgreSQL próprio, em servidores seguros. A transferência de dados segue as salvaguardas adequadas conforme a LGPD e os padrões internacionais de segurança de dados.",
  },
];

function scrollToSection(id: string) {
  return (e: React.MouseEvent) => {
    e.preventDefault();
    document.getElementById(id)?.scrollIntoView({ behavior: "smooth" });
    history.replaceState(null, "", `#${id}`);
  };
}

export default function LandingContent() {
  const { user } = useAuth();
  const painelHref = user ? "/inicio" : "/login";

  const [navSolid, setNavSolid] = useState(false);
  const [cycleIndex, setCycleIndex] = useState(0);
  const [cycleVisible, setCycleVisible] = useState(true);
  const [openFaq, setOpenFaq] = useState<number | null>(null);
  const revealRefs = useRef<Array<HTMLElement | null>>([]);
  const countersRef = useRef<Array<HTMLSpanElement | null>>([]);

  useEffect(() => {
    const onScroll = () => setNavSolid(window.scrollY > 70);
    addEventListener("scroll", onScroll, { passive: true });
    return () => removeEventListener("scroll", onScroll);
  }, []);

  useEffect(() => {
    const id = setInterval(() => {
      setCycleVisible(false);
      setTimeout(() => {
        setCycleIndex((i) => (i + 1) % CYCLE_WORDS.length);
        setCycleVisible(true);
      }, 310);
    }, 2600);
    return () => clearInterval(id);
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
      { threshold: 0.1, rootMargin: "0px 0px -36px 0px" },
    );
    revealRefs.current.forEach((el) => el && obs.observe(el));
    return () => obs.disconnect();
  }, []);

  useEffect(() => {
    const targets = [1000, 100];
    const suffixes = ["+", "%"];
    const cObs = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          const el = entry.target as HTMLSpanElement;
          const idx = countersRef.current.indexOf(el);
          if (idx === -1) return;
          const target = targets[idx];
          const suffix = suffixes[idx];
          const t0 = performance.now();
          const dur = 1600;
          const ease = (t: number) => 1 - Math.pow(1 - t, 3);
          const tick = (now: number) => {
            const p = Math.min((now - t0) / dur, 1);
            el.textContent = Math.round(ease(p) * target).toLocaleString("pt-BR") + (p >= 1 ? suffix : "");
            if (p < 1) requestAnimationFrame(tick);
          };
          requestAnimationFrame(tick);
          cObs.unobserve(el);
        });
      },
      { threshold: 0.6 },
    );
    countersRef.current.forEach((el) => el && cObs.observe(el));
    return () => cObs.disconnect();
  }, []);

  const addReveal = (el: HTMLElement | null) => {
    if (el && !revealRefs.current.includes(el)) revealRefs.current.push(el);
  };

  return (
    <div className="landing">
      {/* NAV */}
      <nav className={`nav${navSolid ? " solid" : ""}`}>
        <a href="#" className="nav-logo">
          <img src={MARCA_URL} alt="GR" />
          <span className="nav-logo-name">Gestão de Rebanho</span>
        </a>
        <div className="nav-links">
          <a href="#features" onClick={scrollToSection("features")}>Funcionalidades</a>
          <a href="#how" onClick={scrollToSection("how")}>Como funciona</a>
          <Link href="/app">Ver o app</Link>
          <a href="#privacy" onClick={scrollToSection("privacy")}>Privacidade</a>
          <Link href={painelHref} className="nav-cta">
            Acessar Painel
          </Link>
        </div>
      </nav>

      {/* HERO */}
      <section className="hero">
        <div className="hero-grid" />
        <div className="hero-glow" />
        <div className="pt" style={{ width: 7, height: 7, background: "rgba(76,175,80,.55)", top: "22%", left: "12%", ["--d" as string]: "9s", ["--dl" as string]: "0s", ["--dy" as string]: "-30px" }} />
        <div className="pt" style={{ width: 4, height: 4, background: "rgba(200,168,75,.6)", top: "65%", left: "7%", ["--d" as string]: "7s", ["--dl" as string]: "1.2s", ["--dy" as string]: "-20px" }} />
        <div className="pt" style={{ width: 5, height: 5, background: "rgba(76,175,80,.45)", top: "40%", right: "10%", ["--d" as string]: "11s", ["--dl" as string]: "2s", ["--dy" as string]: "-25px" }} />
        <div className="pt" style={{ width: 3, height: 3, background: "rgba(200,168,75,.7)", top: "78%", right: "18%", ["--d" as string]: "8s", ["--dl" as string]: ".6s", ["--dy" as string]: "-18px" }} />
        <div className="pt" style={{ width: 6, height: 6, background: "rgba(76,175,80,.35)", top: "14%", right: "30%", ["--d" as string]: "13s", ["--dl" as string]: "3s", ["--dy" as string]: "-22px" }} />

        <div className="hero-inner">
          <div>
            <div className="hero-badge">
              <span className="badge-dot" />
              Gestão pecuária inteligente
            </div>
            <h1 className="hero-h1">
              Seu rebanho
              <br />
              sob{" "}
              <span className="cycle" style={{ opacity: cycleVisible ? 1 : 0, transform: cycleVisible ? "none" : "translateY(-8px)" }}>
                {CYCLE_WORDS[cycleIndex]}
              </span>
              <br />
              total.
            </h1>
            <p className="hero-p">
              Do campo ao painel web — gerencie bovinos, invernadas e manejos sanitários com praticidade, mesmo sem
              internet.
            </p>
            <div className="hero-btns">
              <Link href={painelHref} className="btn-gold">
                <svg width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.2" viewBox="0 0 24 24">
                  <rect x="3" y="3" width="7" height="7" rx="1" />
                  <rect x="14" y="3" width="7" height="7" rx="1" />
                  <rect x="3" y="14" width="7" height="7" rx="1" />
                  <rect x="14" y="14" width="7" height="7" rx="1" />
                </svg>
                Acessar Painel
              </Link>
              <a href="#how" className="btn-ghost" onClick={scrollToSection("how")}>
                Ver como funciona
                <svg width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
                  <path d="M12 5v14M5 12l7 7 7-7" />
                </svg>
              </a>
            </div>
          </div>

          <div className="phone-scene">
            <div className="phone">
              <div className="phone-notch" />
              <div className="phone-screen">
                <div className="pbar">
                  <div className="pg">Bem-vindo de volta 👋</div>
                  <div className="pt2">Fazenda São João 🌿</div>
                </div>
                <div className="psgrid">
                  <div className="psc"><div className="psn">142</div><div className="psl">Bovinos</div></div>
                  <div className="psc"><div className="psn">6</div><div className="psl">Invernadas</div></div>
                  <div className="psc"><div className="psn">138</div><div className="psl">Ativos</div></div>
                  <div className="psc"><div className="psn">12</div><div className="psl">Eventos</div></div>
                </div>
                <div className="psec">Animais recentes</div>
                <div className="prow"><div className="pdot">🐄</div><div><div className="pbn">A-0021</div><div className="pbc">Vaca · Nelore</div></div><div className="ppeso">420 kg</div></div>
                <div className="prow"><div className="pdot">🐄</div><div><div className="pbn">A-0022</div><div className="pbc">Novilha · Brahman</div></div><div className="ppeso">340 kg</div></div>
                <div className="prow"><div className="pdot">🐄</div><div><div className="pbn">A-0023</div><div className="pbc">Bezerro · Angus</div></div><div className="ppeso">185 kg</div></div>
                <div className="prow"><div className="pdot">🐄</div><div><div className="pbn">A-0024</div><div className="pbc">Boi · Nelore</div></div><div className="ppeso">530 kg</div></div>
                <div className="prow"><div className="pdot">🐄</div><div><div className="pbn">A-0025</div><div className="pbc">Vaca · Girolando</div></div><div className="ppeso">390 kg</div></div>
              </div>
            </div>

            <div className="fcard" style={{ right: -22, top: 56, ["--d" as string]: "6.5s", ["--dl" as string]: ".6s", ["--dy" as string]: "-14px" }}>
              <div className="fcl">📍 Invernada A</div>
              <div className="fcv">42</div>
              <div className="fcs">animais · 80% lotação</div>
            </div>
            <div className="fcard" style={{ left: -28, bottom: 72, ["--d" as string]: "8.5s", ["--dl" as string]: "1.8s", ["--dy" as string]: "-10px" }}>
              <div className="fcl">💉 Último manejo</div>
              <div className="fcv" style={{ fontSize: 14, marginTop: 4 }}>Aftosa</div>
              <div className="fcs">12 animais vacinados</div>
            </div>
          </div>
        </div>
      </section>

      {/* STATS */}
      <div className="statsbar">
        <div className="stats-inner">
          <div className="si r" ref={addReveal}>
            <div className="sn"><span ref={(el) => { countersRef.current[0] = el; }}>0+</span></div>
            <div className="sl">Animais gerenciados</div>
          </div>
          <div className="si r" ref={addReveal} style={{ transitionDelay: ".1s" }}>
            <div className="sn"><span ref={(el) => { countersRef.current[1] = el; }}>0%</span></div>
            <div className="sl">Funcional offline</div>
          </div>
          <div className="si r" ref={addReveal} style={{ transitionDelay: ".2s" }}>
            <div className="sn">Grátis</div>
            <div className="sl">Para começar</div>
          </div>
          <div className="si r" ref={addReveal} style={{ transitionDelay: ".3s" }}>
            <div className="sn">LGPD</div>
            <div className="sl">Dados protegidos</div>
          </div>
        </div>
      </div>

      {/* FEATURES */}
      <section className="sec" id="features">
        <div className="sec-in">
          <div className="eyebrow r" ref={addReveal}>Funcionalidades</div>
          <h2 className="sec-h r" ref={addReveal} style={{ transitionDelay: ".1s" }}>
            Tudo que você precisa
            <br />
            em um só lugar
          </h2>
          <div className="feat-grid">
            {[
              ["🐄", "Cadastro de Bovinos", "Registre cada animal com foto, brinco, raça, pelagem, peso e histórico completo. Individual ou em lote."],
              ["🌿", "Controle de Invernadas", "Organize seus pastos, monitore a lotação e saiba quantos animais estão em cada área em tempo real."],
              ["💉", "Manejo Sanitário", "Registre vacinas, vermifugações, tratamentos e curativos com produto, dosagem e responsável."],
              ["📱", "100% Offline", "Funciona na porteira, no curral, na mangueira — sem precisar de sinal. Sincroniza quando conectar."],
              ["☁️", "Backup em Nuvem", "Tudo sincronizado automaticamente com o backend próprio. Troque de celular sem perder nenhum dado."],
              ["🌐", "Painel Web", "Acesse todos os dados no computador com tabelas, filtros, detalhes de animais, invernadas e eventos."],
            ].map(([icon, title, desc], i) => (
              <div className="fcard2 r" ref={addReveal} key={title} style={{ transitionDelay: `${i * 0.08}s` }}>
                <div className="fi2">{icon}</div>
                <div className="fn2">{title}</div>
                <div className="fd2">{desc}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* HOW IT WORKS */}
      <section className="how" id="how">
        <div className="how-in">
          <div className="eyebrow eyebrow-lt r" ref={addReveal}>Como funciona</div>
          <h2 className="sec-h sec-h-lt r" ref={addReveal} style={{ transitionDelay: ".1s" }}>Simples assim</h2>
          <div className="steps">
            {[
              ["📲", "Baixe o aplicativo", "Disponível para Android. Instalação rápida, sem burocracia."],
              ["🐄", "Cadastre seus animais", "Adicione bovinos com foto, brinco, categoria, raça e peso. Um a um ou em lote."],
              ["🌿", "Organize suas invernadas", "Crie seus pastos, defina hectares e aloque os animais com facilidade."],
              ["📊", "Acompanhe tudo", "Estatísticas, histórico de manejos e painel web disponíveis a qualquer hora."],
            ].map(([icon, title, desc], i) => (
              <div className="step r" ref={addReveal} key={title} style={{ transitionDelay: `${i * 0.12}s` }}>
                <div className="step-ico">{icon}</div>
                <div className="step-n">{i + 1}</div>
                <div className="step-t">{title}</div>
                <div className="step-d">{desc}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* SHOWCASE */}
      <section className="showcase">
        <div className="showcase-in">
          <div>
            <div className="eyebrow r" ref={addReveal}>Painel Web</div>
            <h2 className="sec-h r" ref={addReveal} style={{ transitionDelay: ".1s", marginBottom: 36 }}>
              Seus dados em
              <br />
              qualquer tela
            </h2>
            <ul className="bullets">
              {[
                ["🔍", "Busca e filtros avançados", "Encontre qualquer animal por brinco, categoria, invernada ou status em segundos."],
                ["📋", "Detalhes completos ao clicar", "Clique em qualquer animal, invernada ou evento sanitário para ver todos os dados em um painel lateral."],
                ["🔒", "Acesso seguro e privado", "Login com o mesmo e-mail do app. Cada produtor acessa somente os dados da sua fazenda."],
              ].map(([icon, title, desc]) => (
                <li className="bullet r" ref={addReveal} key={title}>
                  <div className="bi">{icon}</div>
                  <div>
                    <div className="bt">{title}</div>
                    <div className="bd">{desc}</div>
                  </div>
                </li>
              ))}
            </ul>
            <Link href={painelHref} className="btn-green" style={{ marginTop: 36, display: "inline-flex" }}>
              Acessar painel
              <svg width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.2" viewBox="0 0 24 24">
                <path d="M5 12h14M12 5l7 7-7 7" />
              </svg>
            </Link>
          </div>
          <div className="tablet-wrap r" ref={addReveal} style={{ transitionDelay: ".15s" }}>
            <div className="tablet">
              <div className="tscr">
                <div className="tmenu">
                  <div className="tmi on">🌿 Invernadas</div>
                  <div className="tmi">🐄 Bovinos</div>
                  <div className="tmi">💉 Sanidade</div>
                </div>
                <div className="tgrid">
                  <div className="tc"><div className="tcn">Pasto A</div><div className="tcv">42</div><div className="tcl">animais</div><div className="tbar"><div className="tfil" style={{ width: "80%", background: "#4CAF50" }} /></div></div>
                  <div className="tc"><div className="tcn">Pasto B</div><div className="tcv">28</div><div className="tcl">animais</div><div className="tbar"><div className="tfil" style={{ width: "55%", background: "#F59E0B" }} /></div></div>
                  <div className="tc"><div className="tcn">Pasto C</div><div className="tcv">61</div><div className="tcl">animais</div><div className="tbar"><div className="tfil" style={{ width: "100%", background: "#EF4444" }} /></div></div>
                  <div className="tc"><div className="tcn">Pasto D</div><div className="tcv">15</div><div className="tcl">animais</div><div className="tbar"><div className="tfil" style={{ width: "30%", background: "#4CAF50" }} /></div></div>
                  <div className="tc"><div className="tcn">Maternid.</div><div className="tcv">8</div><div className="tcl">animais</div><div className="tbar"><div className="tfil" style={{ width: "40%", background: "#4CAF50" }} /></div></div>
                  <div className="tc"><div className="tcn">Recria</div><div className="tcv">35</div><div className="tcl">animais</div><div className="tbar"><div className="tfil" style={{ width: "70%", background: "#F59E0B" }} /></div></div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* PRIVACY */}
      <section className="priv-sec" id="privacy">
        <div className="sec-in">
          <div className="eyebrow r" ref={addReveal}>Privacidade & Segurança</div>
          <h2 className="sec-h r" ref={addReveal} style={{ transitionDelay: ".1s", marginBottom: 0 }}>
            Seus dados são seus.
            <br />
            Sempre.
          </h2>
          <div className="priv-cards" style={{ marginTop: 56 }}>
            <div className="pc r" ref={addReveal}>
              <div className="pc-ico">🔐</div>
              <div className="pc-t">Criptografia total</div>
              <div className="pc-d">Todos os dados trafegam por HTTPS e ficam protegidos por autenticação com renovação automática de sessão, com padrão enterprise.</div>
            </div>
            <div className="pc r" ref={addReveal} style={{ transitionDelay: ".1s" }}>
              <div className="pc-ico">🛡️</div>
              <div className="pc-t">Conformidade LGPD</div>
              <div className="pc-d">Seguimos rigorosamente a Lei Geral de Proteção de Dados. Você decide o que guardar e pode solicitar exclusão a qualquer momento.</div>
            </div>
            <div className="pc r" ref={addReveal} style={{ transitionDelay: ".2s" }}>
              <div className="pc-ico">🚫</div>
              <div className="pc-t">Zero compartilhamento</div>
              <div className="pc-d">Seus dados jamais são vendidos ou compartilhados com terceiros. Sem anúncios, sem rastreadores, sem surpresas.</div>
            </div>
          </div>
          <div className="acc r" ref={addReveal} style={{ transitionDelay: ".3s" }}>
            {FAQ.map((item, i) => (
              <div className={`ai${openFaq === i ? " open" : ""}`} key={item.pergunta}>
                <button type="button" className="ah" onClick={() => setOpenFaq(openFaq === i ? null : i)}>
                  {item.pergunta} <span className="arr">▾</span>
                </button>
                <div className="ab" style={{ maxHeight: openFaq === i ? 400 : 0 }}>
                  {item.resposta}
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="cta">
        <div className="cta-in">
          <div className="cta-pill r" ref={addReveal}>Comece agora — é gratuito</div>
          <h2 className="cta-h r" ref={addReveal} style={{ transitionDelay: ".1s" }}>
            Seu rebanho merece
            <br />
            gestão de qualidade
          </h2>
          <p className="cta-p r" ref={addReveal} style={{ transitionDelay: ".2s" }}>
            Junte-se a produtores que já simplificaram o controle do seu gado com tecnologia feita para o campo
            brasileiro.
          </p>
          <div className="cta-btns r" ref={addReveal} style={{ transitionDelay: ".3s" }}>
            <Link href={painelHref} className="btn-gold">
              <svg width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.2" viewBox="0 0 24 24">
                <rect x="3" y="3" width="7" height="7" rx="1" />
                <rect x="14" y="3" width="7" height="7" rx="1" />
                <rect x="3" y="14" width="7" height="7" rx="1" />
                <rect x="14" y="14" width="7" height="7" rx="1" />
              </svg>
              Acessar Painel Web
            </Link>
            <a href="#features" className="btn-ghost" onClick={scrollToSection("features")}>Ver funcionalidades</a>
          </div>
        </div>
      </section>

      {/* FOOTER */}
      <footer className="landing-footer">
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
                <li><a href="#features" onClick={scrollToSection("features")}>Funcionalidades</a></li>
                <li><a href="#how" onClick={scrollToSection("how")}>Como funciona</a></li>
                <li><Link href="/app">Ver o app</Link></li>
                <li><a href="#privacy" onClick={scrollToSection("privacy")}>Privacidade</a></li>
                <li><Link href={painelHref}>Painel Web</Link></li>
              </ul>
            </div>
            <div>
              <div className="ft-col-h">Legal</div>
              <ul className="ft-links">
                <li><a href="#privacy" onClick={scrollToSection("privacy")}>Política de Privacidade</a></li>
                <li><a href="#privacy" onClick={scrollToSection("privacy")}>Termos de Uso</a></li>
                <li><a href="#privacy" onClick={scrollToSection("privacy")}>LGPD</a></li>
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
