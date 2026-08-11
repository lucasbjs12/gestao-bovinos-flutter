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

## Deploy (Railway)

A imagem Docker (`Dockerfile`, multi-stage) ja foi testada localmente de ponta a ponta (`docker build` + container rodando + `prisma migrate deploy` automatico + registro real funcionando). Passos no Railway:

1. **Criar o projeto**: no painel do Railway, "New Project" → "Deploy from GitHub repo" → selecionar este repositorio. O Railway detecta o `Dockerfile` e o `railway.json` automaticamente (builder `DOCKERFILE`, healthcheck em `/api/v1/health`).
2. **Adicionar o Postgres**: no mesmo projeto, "New" → "Database" → "PostgreSQL". O Railway cria a variavel `DATABASE_URL` sozinho nesse serviço — copie o valor gerado (ou use a referência `${{Postgres.DATABASE_URL}}`) para a variavel `DATABASE_URL` do serviço do backend.
3. **Configurar as variaveis de ambiente** no serviço do backend (aba "Variables"), uma por uma:

   | Variavel | Valor |
   |---|---|
   | `DATABASE_URL` | a do Postgres do Railway (passo 2) |
   | `JWT_ACCESS_SECRET` | gerar um segredo forte novo — **nunca** reaproveitar o do `.env` local (`openssl rand -base64 48` ou similar) |
   | `JWT_ACCESS_EXPIRES_IN` | `15m` |
   | `JWT_REFRESH_EXPIRES_IN_DAYS` | `30` |
   | `CORS_ORIGIN` | dominio de onde o app vai chamar a API (ou `*` enquanto so o app mobile consome, sem navegador) |
   | `RATE_LIMIT_WINDOW_MS` | `900000` |
   | `RATE_LIMIT_MAX` | `100` |
   | `CLOUDINARY_CLOUD_NAME` / `CLOUDINARY_API_KEY` / `CLOUDINARY_API_SECRET` | mesma conta que o app Flutter ja usa (cloud name `duseg2d1m`) — sem isso o endpoint de upload responde 503, o resto da API funciona normal |
   | `NODE_ENV` | `production` |
   | `PORT` | o Railway define sozinho; nao precisa setar |

4. **Primeiro deploy**: o Railway builda a imagem e sobe o container. O `CMD` do Dockerfile roda `prisma migrate deploy` automaticamente antes de iniciar o servidor — as migrations aplicam sozinhas a cada deploy, so o que ainda nao foi aplicado.
5. **Confirmar**: acessar `https://<seu-dominio-railway>/api/v1/health` (deve responder `{success:true,...}`) e `https://<seu-dominio-railway>/api/v1/docs/` (Swagger UI).
6. Domínio: o Railway gera um `*.up.railway.app` gratis; dominio proprio e configuravel depois na aba "Settings" do servico.

**Nao fiz o deploy de verdade** — isso exige acesso a sua conta Railway (e vai gerar custo). Testei a imagem localmente simulando exatamente esse fluxo (build → migrate deploy → health check → registro real), entao o caminho esta validado; falta so você criar o projeto e colar as variaveis acima.

## Migração dos dados do Firestore

Script pontual em `scripts/migrarFirestore.ts` (nao roda no servidor). Le tudo do Firestore/Firebase Auth e grava no Postgres deste backend.

```
npm run migrate:firestore              # dry-run: so gera o relatorio, nao grava nada
npm run migrate:firestore -- --commit  # grava de verdade
```

Pre-requisitos: `FIREBASE_SERVICE_ACCOUNT_PATH` no `.env` apontando pra uma chave de service account (Console Firebase → Configurações do projeto → Contas de serviço → Gerar nova chave privada — **nunca commitar esse `.json`**, o `.gitignore` já bloqueia `*serviceAccount*.json`).

**Antes de rodar `--commit` contra o banco de produção**, leia com atenção:

1. **Senha não migra.** O Firebase Auth guarda senha com o scrypt próprio do Google, não exportável como bcrypt. Todo usuário migrado recebe uma senha placeholder (hash de bytes aleatórios — ninguém sabe essa senha, nem você) e precisa passar por um fluxo de "esqueci minha senha" — **que ainda não existe neste backend**. Sem esse fluxo pronto, ninguém migrado consegue logar. Construir isso é pré-requisito antes de um corte de produção de verdade.
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

- **Fase 0 (fundacao)** concluida: projeto scaffolded, schema Prisma completo, health check funcionando.
- **Fase 1 (auth + multi-tenant)** concluida: `POST /api/v1/auth/registro` (cria usuario + fazenda propria + membro dono), `login`, `refresh` (rotaciona e revoga o token antigo), `logout`, `GET /me`. Middlewares prontos para uso nas proximas fases: `autenticar` (JWT), `carregarFazendaAtiva` (resolve fazenda por header `X-Fazenda-Id` ou fazenda propria), `exigirPapel(...papeis)`, `exigirAssinaturaAtiva` (valida a assinatura do DONO da fazenda, nao do usuario logado). Testado manualmente ponta a ponta incluindo senha errada, e-mail duplicado, reuso de refresh token rotacionado e validacao Zod.
- Registro cria o usuario com `statusAssinatura: "ativo"` (sem gateway de pagamento integrado ainda) — o campo e o middleware sao reais, so falta um fluxo de cobranca que crie usuarios como `pendente`.
- **Fase 2 (recursos operacionais)** concluida: `invernadas`, `bovinos` (+ `PATCH /:id/baixa`), `eventos-sanitarios` (+ M2M com bovinos) e `movimentacoes` (registrar move atualiza `bovino.invernadaId` numa transaction), todos sob `/api/v1/fazendas/:fazendaId/<recurso>`. `carregarFazendaAtiva` resolve a fazenda pelo `:fazendaId` do path (nao mais por header) e confere dono/membro. Testado ponta a ponta: CRUD completo, validacao de referencias entre fazendas (422), isolamento entre fazendas de usuarios diferentes (403), fluxo de movimentacao + baixa.
- **Fase 3 (colaboracao)** concluida: diario de atividades (`GET /atividades`, so leitura), convites (`POST/GET /fazendas/:fazendaId/convites` so dono; `GET/POST /convites/:codigo(/aceitar)` publico pra quem ainda nao e membro) e membros (`GET/DELETE /fazendas/:fazendaId/membros`). RBAC dono-vs-convidado validado de ponta a ponta pela primeira vez com um convidado real: cria mas nao exclui, nao gera convite, perde acesso (403) assim que o dono remove. Convite usa codigo `BOV-XXXXXX` (alfabeto sem 0/O/1/I), expira em 48h, uso unico.
- **Fase 4 (uploads + admin)** concluida: `POST /fazendas/:fazendaId/uploads/assinar?pasta=bovinos|invernadas` gera payload de upload assinado pra Cloudinary (mesma conta que o app Flutter ja usa) sem tocar Firebase — algoritmo de assinatura conferido contra duas implementacoes SHA-1 independentes (.NET e Node). Requer `CLOUDINARY_CLOUD_NAME/API_KEY/API_SECRET` no `.env`; sem isso retorna 503 (nao derruba o servidor). Painel admin (`GET /admin/usuarios`, `PATCH /admin/usuarios/:id/assinatura`) restrito a `isAdmin: true` — usado pra religar `exigirAssinaturaAtiva` quando cobranca real for integrada (ver nota da Fase 1 sobre `statusAssinatura: "ativo"` no registro).
- Nucleo funcional do backend concluido (Fases 0-4).
- **Fase 5 (testes automatizados)** concluida: 16 testes de integracao (vitest+supertest) contra um banco Postgres de teste dedicado (`gestaobovinos_test`), cobrindo auth, CRUD operacional, movimentacao+baixa, RBAC dono-vs-convidado e diario de atividades. `npm run typecheck` valida os tipos de `src` + `test` juntos (o `npm run build` ignora `test/`, so compila o codigo de producao).
- **Fase 6 (documentacao)** concluida: spec OpenAPI 3.0 escrita a mao em `src/docs/openapi.ts` (23 rotas, 28 schemas, bate exatamente com os DTOs Zod e as regras de RBAC reais) servida via Swagger UI em `GET /api/v1/docs/` e JSON cru em `GET /api/v1/docs/openapi.json`. `helmet` roda com `contentSecurityPolicy: false` (API pura JSON pro app Flutter, CSP e protecao de navegador; tambem evita bloquear os scripts do Swagger UI).
- **Fase 7 (deploy)** preparada: `Dockerfile` multi-stage + `railway.json` + `.dockerignore` criados e **testados localmente** (`docker build` + container rodando contra o Postgres local + `prisma migrate deploy` automatico no boot + registro real via HTTP, tudo dentro do container). `prisma` (CLI) movido de devDependencies pra dependencies — precisa dele em runtime pra rodar `migrate deploy` na imagem de producao. Deploy de verdade no Railway fica pendente de acesso a conta do usuario (ver secao "Deploy" acima com o checklist de variaveis).
- **Fase 8 (script de migração do Firestore)** feita: `scripts/migrarFirestore.ts` — ver seção "Migração dos dados do Firestore" acima. Cobre usuarios (com fallback pro Firebase Auth quando falta o doc), fazendas, membros, invernadas, bovinos (+ referencia de mae), baixas, eventos sanitarios (+ M2M), movimentacoes e convites. Reaproveita os `syncId` (já são UUID v4) como PK do Postgres quando validos, evitando uma tabela de mapeamento de ids para a maioria das entidades. **Ainda não rodado contra dados reais** — sem credenciais de Firebase neste ambiente. Bloqueador antes de um corte de produção: não existe fluxo de "esqueci minha senha" no backend, e usuários migrados não têm como recuperar acesso sem ele.
- Proxima fase: troca da camada remota no app Flutter (Firebase → REST).
