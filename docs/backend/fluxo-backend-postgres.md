# Fluxo: Backend próprio (Node.js/Express + PostgreSQL) para o GestaoBovinosApp

> Decisão registrada em 2026-07-30: o usuário optou por seguir com backend próprio (reversão da decisão anterior de 2026-07-08 de ficar no Firebase/migrar para Supabase só quando necessário). Este documento assume que o Firestore será **substituído**, não espelhado.

## 0. Onde partimos (estado real do app hoje)

- **Stack atual:** Flutter + Provider, SQLite local (sqflite, local-first) + Firebase Auth + Firestore (sync em nuvem) + Cloud Function `assinarUploadCloudinary` + upload direto pro Cloudinary.
- **Multi-tenant:** cada "fazenda" = 1 dono, `fazendaId == uid do dono`. Papéis hoje no código committado: `dono` / `convidado` (rules `firestore.rules`). Há trabalho não commitado (fase 4, working tree) introduzindo nomenclatura "capataz" — **precisa reconciliar qual nome de papel vale antes de fixar o enum no Postgres**.
- **Entidades:** Bovino, BaixaBovino, Invernada, MovimentacaoInvernada, EventoSanitario (M2M com Bovino), Atividade (log imutável), Convite, Membro, Usuario/Assinatura. RFID (`leitura_rfid`) é local-only hoje, nunca sincronizado.
- **Padrão de sync atual:** `syncId` (UUID) gerado no cliente é o id estável; SQLite usa `id` inteiro autoincrement + `syncId`. No backend novo, isso desaparece: **cada tabela usa UUID como PK única**, fim da duplicidade local-id/syncId.
- **Fotos:** URL simples (Cloudinary `secure_url`) salva como string no campo `foto`/`urlFoto`. Sem tabela de mídia.

Esse levantamento completo está no relatório de exploração desta conversa — serve de fonte de verdade para o schema abaixo.

---

## 1. Stack proposta

| Camada | Escolha | Motivo |
|---|---|---|
| Runtime | Node.js 20+ / TypeScript | tipagem ajuda com o volume de entidades e DTOs |
| Framework | Express | pedido explícito no prompt; simples de auditar |
| ORM/Query | Prisma | migrations declarativas, gera types, reduz SQL manual (menos superfície pra SQL injection) |
| Validação | Zod | valida body/query, gera tipos, integra bem com Express middleware |
| Auth | JWT (access curto, ~15min) + refresh token (rotacionado, tabela `refresh_tokens`) + bcrypt | pedido explícito |
| Docs | swagger-jsdoc + swagger-ui-express (OpenAPI 3) | |
| Logs | pino (+ pino-http) | logs estruturados, fácil de mandar pra um agregador depois |
| Rate limit | express-rate-limit | por IP e por usuário nas rotas de auth |
| Segurança | helmet, cors configurável, express-validator/Zod para sanitização | |
| Testes | vitest ou jest + supertest | rotas, services, repositories |
| Upload de foto | endpoint que gera **presigned POST** (S3-compatible: Cloudflare R2 ou AWS S3) | substitui a Cloud Function do Cloudinary sem custo extra do Firebase |
| Deploy | Docker Compose (app + Postgres) para começar; Railway/Fly.io/VPS depois | |

---

## 2. Modelo de dados (PostgreSQL)

UUID como PK em toda tabela sync-relevante (`gen_random_uuid()`, extensão `pgcrypto`).

```
usuarios
  id UUID PK
  nome TEXT NOT NULL
  email TEXT UNIQUE NOT NULL
  senha_hash TEXT NOT NULL
  is_admin BOOLEAN NOT NULL DEFAULT false
  status_assinatura TEXT NOT NULL DEFAULT 'pendente'  -- pendente|ativo|bloqueado|vencido
  plano TEXT
  vencimento TIMESTAMPTZ
  criado_em TIMESTAMPTZ NOT NULL DEFAULT now()

refresh_tokens
  id UUID PK
  usuario_id UUID FK -> usuarios ON DELETE CASCADE
  token_hash TEXT NOT NULL
  expira_em TIMESTAMPTZ NOT NULL
  revogado_em TIMESTAMPTZ

fazendas
  id UUID PK
  dono_id UUID FK -> usuarios NOT NULL         -- fim do "fazendaId == uid"; agora é FK real
  nome TEXT NOT NULL
  criado_em TIMESTAMPTZ NOT NULL DEFAULT now()

membros
  fazenda_id UUID FK -> fazendas ON DELETE CASCADE
  usuario_id UUID FK -> usuarios ON DELETE CASCADE
  papel TEXT NOT NULL CHECK (papel IN ('dono','convidado'))
  nome TEXT
  desde TIMESTAMPTZ NOT NULL DEFAULT now()
  PRIMARY KEY (fazenda_id, usuario_id)

convites
  codigo TEXT PK                                -- BOV-XXXXXX
  fazenda_id UUID FK -> fazendas NOT NULL
  papel TEXT NOT NULL DEFAULT 'convidado'
  criado_por UUID FK -> usuarios
  criado_em TIMESTAMPTZ NOT NULL DEFAULT now()
  expira_em TIMESTAMPTZ NOT NULL
  usado BOOLEAN NOT NULL DEFAULT false
  usado_por UUID FK -> usuarios

invernadas
  id UUID PK
  fazenda_id UUID FK -> fazendas ON DELETE CASCADE NOT NULL
  descricao TEXT NOT NULL
  hectares NUMERIC
  url_foto TEXT
  observacoes TEXT
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT now()

bovinos
  id UUID PK
  fazenda_id UUID FK -> fazendas ON DELETE CASCADE NOT NULL
  nome_animal TEXT
  codigo_epc TEXT
  codigo_interno TEXT
  numero_brinco TEXT NOT NULL
  raca TEXT
  data_nascimento DATE
  peso_atual_kg NUMERIC
  pelagem TEXT
  categoria TEXT NOT NULL CHECK (categoria IN ('Vaca','Novilha','Terneira','Terneiro','Novilho','Touro','Boi'))
  status TEXT NOT NULL DEFAULT 'Ativo'
  origem TEXT
  observacoes TEXT
  foto TEXT
  invernada_id UUID FK -> invernadas ON DELETE SET NULL
  id_mae UUID FK -> bovinos ON DELETE SET NULL
  esta_de_cria BOOLEAN NOT NULL DEFAULT false
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT now()
  INDEX (fazenda_id, numero_brinco), INDEX (invernada_id), INDEX (id_mae)

baixas_bovinos
  id UUID PK
  bovino_id UUID FK -> bovinos ON DELETE CASCADE NOT NULL
  motivo TEXT NOT NULL         -- Morte|Venda|Furto|Outros (confirmar lista exata na UI)
  observacoes TEXT
  data_baixa DATE NOT NULL

movimentacoes_invernada
  id UUID PK
  fazenda_id UUID FK -> fazendas NOT NULL
  bovino_id UUID FK -> bovinos NOT NULL
  data DATE NOT NULL
  invernada_anterior_id UUID FK -> invernadas
  nova_invernada_id UUID FK -> invernadas
  responsavel TEXT
  observacoes TEXT

eventos_sanitarios
  id UUID PK
  fazenda_id UUID FK -> fazendas ON DELETE CASCADE NOT NULL
  tipo TEXT NOT NULL CHECK (tipo IN ('Vacinação','Vermifugação','Medicação','Castração','Banho','Outros'))
  data_evento DATE
  invernada_id UUID FK -> invernadas
  produto_utilizado TEXT
  dosagem TEXT
  responsavel TEXT
  observacoes TEXT

evento_sanitario_bovino
  evento_id UUID FK -> eventos_sanitarios ON DELETE CASCADE
  bovino_id UUID FK -> bovinos ON DELETE CASCADE
  PRIMARY KEY (evento_id, bovino_id)

atividades   -- log imutável, sem UPDATE/DELETE via API (só INSERT/SELECT)
  id UUID PK
  fazenda_id UUID FK -> fazendas ON DELETE CASCADE NOT NULL
  autor_id UUID FK -> usuarios NOT NULL
  autor_nome TEXT
  acao TEXT NOT NULL
  descricao TEXT NOT NULL
  criado_em TIMESTAMPTZ NOT NULL DEFAULT now()
  INDEX (fazenda_id, criado_em DESC)

leituras_rfid   -- opcional sincronizar; hoje é local-only no app
  id UUID PK
  bovino_id UUID FK -> bovinos NOT NULL
  antena TEXT
  registrado_em TIMESTAMPTZ NOT NULL
```

Todas as tabelas com `fazenda_id` levam índice composto `(fazenda_id, ...)` pensando em paginação/filtro por fazenda (todo endpoint de listagem é sempre escopado por fazenda).

---

## 3. Autenticação e RBAC

- `POST /api/v1/auth/registro` (cria usuário + fazenda própria, `dono` implícito)
- `POST /api/v1/auth/login` → `{ accessToken, refreshToken }`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout` (revoga refresh token)
- Middleware `autenticar`: valida JWT, popula `req.usuario`.
- Middleware `carregarFazendaAtiva`: resolve `fazendaId` a partir do `:fazendaId` no path (rotas montadas como `/fazendas/:fazendaId/...`) e verifica associação em `membros`/`fazendas.dono_id` (implementado assim em vez do header `X-Fazenda-Id` cogitado inicialmente — mais RESTful e mais fácil de testar).
- Middleware `exigirPapel('dono' | 'capataz')`: replica a matriz atual —
  - leitura/criação/edição de recursos operacionais: qualquer membro
  - exclusão (bovino, invernada, evento, fazenda, membro): só dono
  - `atividades`: só INSERT, autor obrigatoriamente = usuário autenticado; nunca UPDATE
- Reativar `assinaturaLiberada`: middleware opcional `exigirAssinaturaAtiva` (hoje sempre `true`, plugável quando cobrança for ligada) — regra já existe comentada no `firestore.rules`, só precisa virar guard real.

---

## 4. Endpoints por recurso (padrão REST, `/api/v1/...`)

Todos os recursos abaixo (exceto `auth` e `admin`) são escopados por fazenda: `/api/v1/fazendas/:fazendaId/<recurso>`.

| Recurso | Rotas |
|---|---|
| bovinos | GET (lista, paginação+filtro+busca+ordenação), GET /:id, POST, PUT /:id, PATCH /:id/baixa, DELETE /:id (dono) |
| invernadas | GET, GET /:id, POST, PUT /:id, DELETE /:id (dono), GET /:id/movimentacoes |
| eventos-sanitarios | GET, GET /:id, POST (com `bovinoIds[]`), PUT /:id, DELETE /:id (dono) |
| atividades | GET (paginado, só leitura), POST (interno, chamado pelos services — não exposto livre) |
| membros | GET, DELETE /:usuarioId (dono) |
| convites | POST (gerar, dono), POST /:codigo/aceitar, GET /:codigo (validar) |
| uploads | POST /uploads/assinar (retorna presigned POST) |
| admin (usuarios/assinaturas) | GET /usuarios (admin), PATCH /usuarios/:id/assinatura (admin) |

Resposta padronizada:
```json
{ "success": true, "message": "...", "data": { } }
{ "success": false, "message": "...", "error": { "code": "...", "details": [] } }
```

---

## 5. Ordem de implementação (fluxo passo a passo)

1. **Fase 0 — Fundação**
   - Scaffold do projeto (`backend/`): TypeScript, Express, Prisma, estrutura de pastas (`src/{config,routes,controllers,services,repositories,middlewares,dtos,utils,exceptions}`).
   - `docker-compose.yml` com Postgres local, `.env.example`.
   - Migration inicial com o schema da seção 2 (Prisma migrate).

2. **Fase 1 — Auth + multi-tenant**
   - Modelos `usuarios`, `fazendas`, `membros`, `convites`, `refresh_tokens`.
   - Registro, login, refresh, middlewares de auth/tenant/papel.
   - Testes de auth (registro, login, token expirado, refresh, RBAC negando dono-only).

3. **Fase 2 — Recursos operacionais**
   - `invernadas` → `bovinos` (+ baixa) → `eventos_sanitarios` (+ M2M) → `movimentacoes_invernada`, nessa ordem (respeita as FKs).
   - Cada recurso: repository → service → controller → rotas → validação Zod → testes.

4. **Fase 3 — Auditoria e colaboração**
   - `atividades` (toda mutação relevante nos services acima dispara um insert de atividade — igual ao app hoje).
   - `convites`/`membros` fluxo completo (gerar código, aceitar, listar, remover).

5. **Fase 4 — Uploads e admin**
   - Endpoint de upload assinado (R2/S3).
   - Painel admin: listar/gerenciar assinatura de usuários, reativar `exigirAssinaturaAtiva`.

6. **Fase 5 — Qualidade transversal**
   - Middleware global de erros (`AppError` tipado → nunca vaza stack trace).
   - Logs estruturados (pino) nas mutações e falhas.
   - Rate limiting em `/auth/*`.
   - Swagger/OpenAPI cobrindo tudo acima.
   - Coleção Postman/Insomnia exportada.

7. **Fase 6 — Migração de dados existentes**
   - Script único (Node script ou Cloud Function temporária) lendo Firestore (`fazendas/*`) e populando o Postgres novo, gerando UUIDs onde só existia `syncId`/id local, resolvendo `dono_id` = uid atual do Firebase Auth (guardar o `firebase_uid` como coluna extra em `usuarios` até todo mundo trocar de senha/login).
   - Rodar em modo dry-run primeiro, validar contagens por tabela antes do corte real.

8. **Fase 7 — App Flutter**
   - Trocar `FirebaseAuth` por um `AuthService` que fala com `/api/v1/auth/*`, guardando JWT+refresh no `flutter_secure_storage`.
   - Trocar os *remote repositories* (Firestore) por repositories HTTP (Dio/http), mantendo o SQLite local exatamente como está (continua local-first) — só troca a camada de sync remoto.
   - Trocar `cloudinary_service.dart` para chamar `/uploads/assinar` do novo backend em vez da Cloud Function.
   - Manter o app funcionando com Firebase até o backend novo estar 100% testado; cutover controlado (feature flag ou build separado) para não perder dados de produção no meio do caminho.

9. **Fase 8 — Deploy e corte**
   - Subir Postgres gerenciado (Railway/Neon/RDS) + API (Fly.io/Railway/VPS).
   - Congelar escrita no Firestore, rodar migração final, apontar app pro backend novo, monitorar.
   - Manter Firestore como backup fria por um tempo antes de desligar de vez.

---

## 6. Decisões travadas (2026-07-31)

1. **Papel de colaborador**: `convidado` (mantém o nome já usado no código committed; ignora a tentativa de renomear pra "capataz" no working tree não commitado).
2. **Motivos de baixa**: enum fixo `Morte | Venda | Furto | Outros` (`CHECK` constraint na tabela `baixas_bovinos`).
3. **Cobrança/assinatura**: `exigirAssinaturaAtiva` **ativo já na Fase 1** — login/rotas operacionais verificam `status_assinatura = 'ativo'` desde o início (não fica liberado geral como no Firebase hoje).
4. **RFID**: fora de escopo por enquanto — sem tabela `leituras_rfid` na v1 do backend, sem endpoint. Revisitar quando o app for usar RFID de verdade.
5. **Hospedagem**: **Railway** — Postgres gerenciado + deploy do Node a partir do GitHub, tudo num único painel, custo baixo (~US$5/mês) pro estágio atual do projeto.

Com isso, a Fase 0 (scaffold do backend) está em andamento — ver `backend/` no repo.
