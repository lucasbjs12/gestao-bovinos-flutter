# Backend GestaoBovinosApp

API REST propria (Node.js/TypeScript + Express + PostgreSQL via Prisma) que substitui o Firebase Auth + Firestore do app Flutter. Contexto completo e fases do projeto: `../docs/backend/fluxo-backend-postgres.md`.

## Rodando localmente

1. Instalar dependencias:
   ```
   npm install
   ```
2. Copiar `.env.example` para `.env` e ajustar `JWT_ACCESS_SECRET`.
3. Subir o Postgres local:
   ```
   docker compose up -d
   ```
4. Rodar as migrations:
   ```
   npm run prisma:migrate
   ```
5. Subir a API em modo dev:
   ```
   npm run dev
   ```
6. Testar: `GET http://localhost:3000/api/v1/health`

## Rodando os testes automatizados

Os testes usam um banco Postgres **separado** do de desenvolvimento (as tabelas sao limpas entre arquivos de teste).

1. Criar o banco de teste uma vez: `docker exec backend-postgres-1 psql -U gestaobovinos -d gestaobovinos -c "CREATE DATABASE gestaobovinos_test"`
2. Garantir que `DATABASE_URL_TEST` esta no `.env` (ja vem no `.env.example`).
3. Aplicar as migrations nesse banco: `$env:DATABASE_URL = $env:DATABASE_URL_TEST; npm run prisma:deploy` (troque para a sintaxe do seu shell)
4. Rodar a suite: `npm test` (ou `npm run test:watch` para modo watch)
5. Checar tipos (src + test): `npm run typecheck`

## Deploy (Render)

Em produção desde agosto/2026, em [api.gestaobovinos.com.br](https://api.gestaobovinos.com.br). Passos para replicar:

1. **Banco**: Render → New → PostgreSQL (plano Free serve para começar).
2. **Web Service**: New → Web Service → conectar o repositório. Root Directory vazio, **Dockerfile Path** `backend/Dockerfile`, **Docker Build Context Directory** `backend` (o Render soma Root Directory + esses caminhos, então se usar Root Directory `backend` os outros dois viram só `Dockerfile` e `.`).
3. **Health Check Path**: `/api/v1/health`.
4. **Variáveis de ambiente** no serviço:

   | Variável | Valor |
   |---|---|
   | `DATABASE_URL` | Internal Database URL do Postgres criado no passo 1 |
   | `JWT_ACCESS_SECRET` | segredo forte novo — **nunca** reaproveitar o do `.env` local (`openssl rand -base64 48` ou similar) |
   | `JWT_ACCESS_EXPIRES_IN` | `15m` |
   | `JWT_REFRESH_EXPIRES_IN_DAYS` | `30` |
   | `CORS_ORIGIN` | domínio(s) do site, separados por vírgula se houver mais de um (ex: `https://gestaobovinos.com.br,https://www.gestaobovinos.com.br` — raiz e `www` são origens diferentes pro navegador mesmo com um redirecionando pro outro) |
   | `FRONTEND_URL` | domínio do site (usado nos links dos e-mails) |
   | `RATE_LIMIT_WINDOW_MS` | `900000` |
   | `RATE_LIMIT_MAX` | `100` |
   | `CLOUDINARY_CLOUD_NAME` / `CLOUDINARY_API_KEY` / `CLOUDINARY_API_SECRET` | conta usada pelo app Flutter para fotos — sem isso o endpoint de upload responde 503, o resto da API funciona normal |
   | `RESEND_API_KEY` / `RESEND_FROM_EMAIL` | conta Resend com domínio verificado — sem isso, e-mails de reset de senha/confirmação de cadastro respondem 503 (não bloqueia cadastro/login) |
   | `NODE_ENV` | `production` |

5. **Primeiro deploy**: o Render builda a imagem Docker e sobe o container. O `CMD` do Dockerfile roda `prisma migrate deploy` automaticamente antes de iniciar o servidor — as migrations aplicam sozinhas a cada deploy, só o que ainda não foi aplicado.
6. **Domínio próprio**: Settings → Custom Domains do Web Service, adiciona o subdomínio (ex: `api.seudominio.com`) e configura o `CNAME` que ele mostrar no DNS do seu domínio.
7. **Keep-alive**: o serviço faz self-ping em `/api/v1/health` a cada 10min (`src/utils/keepAlive.ts`) para evitar o "sleep" por inatividade do plano free do Render — só ativa quando a env var `RENDER_EXTERNAL_URL` existe (o próprio Render injeta essa variável; em dev local fica desligado sozinho).

## Migração dos dados do Firestore

Script pontual em `scripts/migrarFirestore.ts` (nao roda no servidor). Le tudo do Firestore/Firebase Auth e grava no Postgres deste backend.

```
npm run migrate:firestore              # dry-run: so gera o relatorio, nao grava nada
npm run migrate:firestore -- --commit  # grava de verdade
```

Pre-requisitos: `FIREBASE_SERVICE_ACCOUNT_PATH` no `.env` apontando pra uma chave de service account (Console Firebase → Configurações do projeto → Contas de serviço → Gerar nova chave privada — **nunca commitar esse `.json`**, o `.gitignore` já bloqueia `*serviceAccount*.json`).

**Antes de rodar `--commit` contra o banco de produção**, leia com atenção:

1. **Senha não migra.** O Firebase Auth guarda senha com o scrypt próprio do Google, não exportável como bcrypt. Todo usuário migrado recebe uma senha placeholder (hash de bytes aleatórios — ninguém sabe essa senha, nem você) e precisa passar pelo fluxo de "esqueci minha senha" (`POST /auth/esqueci-senha`, já implementado — ver seção "Status") antes de conseguir logar.
2. Nem todo usuário tem doc em `usuarios/{uid}` no Firestore (bug histórico conhecido do app — `garantirUsuario` nunca era chamado). O script cai pro Firebase Auth (`admin.auth().getUser`) quando o doc não existe, e loga um aviso no relatório.
3. RFID fica de fora (decisão já tomada — ver seção 6 do fluxo de migração).
4. **Nunca rodado contra dados reais** — não tenho credenciais de Firebase neste ambiente. A lógica foi revisada com cuidado mas só validada por leitura de código, não em runtime. **Rode `--dry-run` primeiro**, confira o relatório (`relatorio-migracao-*.json`, também no `.gitignore`) com atenção antes de cogitar `--commit`, e teste `--commit` contra um banco Postgres vazio de teste antes de rodar contra produção.

## Estrutura

```
src/
  config/        env, logger, cliente Prisma
  routes/        definicao das rotas Express
  controllers/   recebem req/res, chamam services
  services/       regra de negocio
  repositories/   acesso ao banco (Prisma)
  middlewares/    auth, erros, validacao
  dtos/           schemas Zod de entrada/saida
  utils/          helpers (resposta padrao, etc.)
  exceptions/     AppError e afins
prisma/
  schema.prisma  modelo de dados completo
test/
  helpers/       app Express de teste, registrarUsuario(), limparBanco()
  *.test.ts      testes de integracao via supertest (auth, recursos, colaboracao)
```

## Status

Em produção desde agosto/2026. Núcleo funcional completo:

- **Auth**: registro (cria usuário + fazenda própria + membro dono), login, refresh (rotaciona e revoga o token antigo), logout, `GET /me`, alterar senha, excluir conta, **esqueci senha** e **confirmação de e-mail no cadastro** (ambos com e-mail HTML via Resend, token de uso único, expiração e revogação de sessões antigas ao redefinir senha).
- **Multi-tenant + RBAC**: cada usuário tem uma fazenda própria; `carregarFazendaAtiva` resolve a fazenda pelo `:fazendaId` do path e confere dono/membro; `exigirPapel(...papeis)` e `exigirAssinaturaAtiva` (valida a assinatura do dono da fazenda). Registro cria o usuário com `statusAssinatura: "ativo"` (sem gateway de pagamento integrado ainda — campo e middleware são reais, só falta um fluxo de cobrança que crie usuários como `pendente`).
- **Recursos operacionais**: `invernadas`, `bovinos` (+ baixa/reativação), `eventos-sanitarios` (M2M com bovinos) e `movimentacoes` (atualiza `bovino.invernadaId` numa transaction), todos sob `/api/v1/fazendas/:fazendaId/<recurso>`.
- **Colaboração**: diário de atividades, convites por código (`BOV-XXXXXX`, expira em 48h, uso único) e membros (dono/convidado).
- **Uploads**: `GET /fazendas/:fazendaId/uploads/assinar` gera payload de upload assinado pra Cloudinary (algoritmo de assinatura conferido contra duas implementações SHA-1 independentes). Sem `CLOUDINARY_*` no `.env`, retorna 503 sem derrubar o servidor.
- **Admin**: `GET /admin/usuarios`, `PATCH /admin/usuarios/:id/assinatura`, restrito a `isAdmin: true`.
- **Testes**: suíte de integração (vitest + supertest) contra um banco Postgres de teste dedicado (`gestaobovinos_test`), cobrindo auth, CRUD operacional, movimentação+baixa e RBAC. `npm run typecheck` valida os tipos de `src` + `test` juntos.
- **Documentação**: spec OpenAPI 3.0 escrita a mão em `src/docs/openapi.ts`, servida via Swagger UI em `GET /api/v1/docs/`.
- **Deploy**: Docker (`Dockerfile` multi-stage) no Render, com domínio próprio, migrations automáticas no boot e self-ping anti-sleep (ver seção "Deploy" acima).
- **Segurança**: rate limiting (global + login/registro), headers via `helmet`, redação de tokens/cookies nos logs (`pino` `redact`), CORS restrito a origens explícitas.

Pendências conhecidas: gateway de pagamento real (assinatura hoje é sempre `ativo` no registro); script de migração pontual do Firestore (`scripts/migrarFirestore.ts`, ver seção acima) nunca rodado contra dados reais.
