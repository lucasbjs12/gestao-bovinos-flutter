# Site — Gestão de Rebanho

Painel web + landing page do Gestão de Rebanho (Next.js, App Router). Consome a mesma API REST (`../backend/`) que o app Flutter, com as mesmas credenciais de login.

Em produção em [gestaobovinos.com.br](https://gestaobovinos.com.br).

## Rodando localmente

```bash
npm install
npm run dev
```

Abre em [http://localhost:3000](http://localhost:3000) (ou outra porta, se a 3000 já estiver em uso pelo backend local).

Por padrão aponta para a API de produção (`NEXT_PUBLIC_API_URL` não configurado → usa `https://api.gestaobovinos.com.br/api/v1`, ver `src/lib/backend-config.ts`). Para testar contra o backend local (ver `../backend/README.md`), crie um `.env.local`:

```
NEXT_PUBLIC_API_URL=http://localhost:3000/api/v1
```

## Estrutura

```
src/
  app/
    (painel)/        # Rotas autenticadas: bovinos, invernadas, eventos, admin, perfil...
    login/, cadastro-*/, esqueci-senha/, redefinir-senha/, verificar-email/
    page.tsx          # Landing page publica (marketing + privacidade)
    app/               # Pagina de capturas de tela do app
    LandingContent.tsx / landing.css
  components/
    ui/                # Componentes reutilizaveis (Button, Card, FormField...)
  lib/
    api-client.ts       # Cliente HTTP com refresh automatico de token em 401
    backend-auth.ts      # Login, registro, esqueci senha, verificar e-mail
    auth-context.tsx      # Provider de sessao (React Context)
    api/                   # Um arquivo por recurso (bovinos, invernadas, eventos...)
```

## Deploy (Vercel)

1. Conectar o repositório no Vercel, **Root Directory** = `web`.
2. Variável de ambiente: `NEXT_PUBLIC_API_URL` = `https://api.gestaobovinos.com.br/api/v1` (Production + Preview).
3. Domínio próprio: Settings → Domains, adicionar o domínio — o Vercel mostra os registros DNS (`A` para o domínio raiz, `CNAME` para `www`) para configurar no seu provedor de DNS.
4. Deploy automático a cada push na branch `master`.

Certifique-se de que `CORS_ORIGIN` no backend (Render) inclui o(s) domínio(s) do site — ver `../backend/README.md`.
