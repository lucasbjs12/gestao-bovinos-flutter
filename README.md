# Gestão de Rebanho

Sistema completo de **gestão de rebanho bovino** para o produtor rural: app mobile (Flutter), painel web (Next.js) e API própria (Node/Express + PostgreSQL). Permite cadastrar e acompanhar animais, invernadas, eventos sanitários (vacinação, vermifugação, medicação etc.) e baixas — funciona **offline no campo** e sincroniza automaticamente quando há conexão.

🔗 **Site**: [gestaobovinos.com.br](https://gestaobovinos.com.br)
🔗 **API**: [api.gestaobovinos.com.br/api/v1/health](https://api.gestaobovinos.com.br/api/v1/health)

---

## Estrutura do repositório

Monorepo com três partes independentes:

```
.
├── lib/          # App Flutter (Android/iOS) — este README
├── backend/      # API REST propria (Node/Express + Prisma + PostgreSQL) — backend/README.md
├── web/          # Painel web + landing page (Next.js) — web/README.md
└── docs/         # Landing estatica antiga (Firebase Hosting, GitHub Pages)
```

Cada pasta (`backend/`, `web/`) tem seu próprio README com instruções específicas de setup e deploy.

---

## Funcionalidades

### Bovinos
- Cadastro completo: brinco, nome, raça, categoria, sexo, peso, pelagem, origem, foto e observações
- Vínculo mãe ↔ terneiro
- Foto do animal com upload para Cloudinary e fallback local
- Visualização em tela cheia com pinch-to-zoom
- Histórico de todos os eventos sanitários do animal
- Ordenação da lista por brinco, nome, categoria, invernada ou peso
- Filtro por categoria e busca por brinco/nome
- Seleção em batch (long-press): criar evento ou dar baixa em lote
- Baixa individual com motivo (Vendido, Abatido, Morte, Outro)

### Invernadas (pastagens)
- Cadastro e edição de invernadas
- Visualização dos animais em cada invernada
- Histórico de movimentações (transferências entre invernadas)
- Atalho para criar evento sanitário para todos os animais da invernada

### Eventos Sanitários
- Tipos: Vacinação, Vermifugação, Medicação, Castração, Banho
- Formulário em **2 etapas**: cabeçalho (tipo, data, produto, dosagem, responsável) → seleção de animais
- Seleção de animais com busca, filtro por invernada e "selecionar todos"
- Rascunho automático — se sair da tela, o preenchimento é salvo e pode ser restaurado
- Filtros por tipo e busca por produto/responsável
- Paginação com "Carregar mais"

### Dashboard
- Total do rebanho com breakdown por categoria (vacas, novilhos, terneiros, outros)
- Alertas de animais sem manejo sanitário há mais de 30/60/90 dias
- Alerta de terneiros com categoria indefinida
- Acesso rápido às seções principais

### Multi-usuário e colaboração
- Cada usuário tem uma fazenda própria; convites por código para adicionar membros (papel dono/convidado)
- Diário de atividades — registro de quem fez o quê na fazenda
- Painel admin (assinatura, usuários)

### Conta
- Cadastro, login, recuperação de senha e confirmação de e-mail (com template visual próprio)
- Painel web usa as mesmas credenciais do app

### Outros
- Leitura de RFID
- Histórico de animais baixados com filtro por motivo e opção de reativação
- **Funcionamento 100% offline**: dados salvos localmente (SQLite) e sincronizados com o backend por polling quando há conexão; escritas feitas offline entram numa fila (*outbox*) e são reenviadas automaticamente

---

## Tecnologias

| Camada | Tecnologia |
|---|---|
| App mobile | Flutter 3.x / Dart 3.x |
| Painel web | Next.js (App Router) + TypeScript + Tailwind |
| API | Node.js + Express + TypeScript |
| Banco (produção) | PostgreSQL via Prisma ORM |
| Banco local (app) | SQLite via `sqflite` |
| Autenticação | JWT próprio (access + refresh token, rotação automática) |
| Estado (app) | Provider |
| Fotos | Cloudinary (upload assinado pelo backend) |
| E-mail | Resend |
| Hospedagem | Render (API) + Vercel (site) |
| Testes | `flutter_test` (app) · Vitest + Supertest (backend) |

---

## Arquitetura

### App Flutter — offline-first

```
lib/
├── core/
│   ├── api/              # ApiClient (JWT, refresh automatico em 401)
│   ├── db/               # Banco SQLite (AppDatabase — uma instancia por fazenda)
│   ├── sync/              # Outbox (fila de escrita offline)
│   ├── routes/            # Rotas nomeadas
│   ├── storage/            # Cloudinary
│   └── utils/              # Utilitarios (foto, data, etc.)
│
├── features/
│   ├── auth/               # Login, cadastro de fazenda, convite
│   ├── bovinos/            # Cadastro, detalhe, lista, baixa, animais baixados
│   ├── eventos_sanitarios/ # CRUD de eventos, rascunho
│   ├── fazenda/            # Membros, seletor de fazenda ativa
│   ├── home/                # Dashboard
│   ├── invernadas/          # Pastagens e movimentacoes
│   ├── perfil/               # Configuracoes do usuario
│   ├── rfid/                  # Leitura de tags RFID
│   └── shell/                  # Navegacao principal (bottom nav)
│
├── sync/                # PollingSyncService — sincronizacao periodica com o backend
└── main.dart
```

```
UI (Screen)
   ↕ Provider (ChangeNotifier)
LocalRepository (SQLite)   ←→   RemoteRepository (API REST)   ←→   Outbox (fila offline)
```

- A **UI** lê estado do **Provider** e dispara ações
- Toda escrita vai primeiro pro SQLite local; se a chamada à API falhar (offline/erro transitório), entra na **Outbox** e é reenviada depois
- O **PollingSyncService** busca periodicamente o estado atual do backend e atualiza o SQLite, protegendo itens com escrita pendente na Outbox
- Erros permanentes (4xx de validação) são descartados da fila em vez de travá-la; erros transitórios (rede, 5xx, 401, 429) ficam retentando

### Backend + web

Ver `backend/README.md` e `web/README.md` para detalhes de arquitetura, variáveis de ambiente e deploy de cada parte.

---

## Como rodar

### App Flutter

**Pré-requisitos**: [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.x+, Android Studio com emulador (ou dispositivo físico).

```bash
git clone https://github.com/lucasbjs12/gestao-bovinos-flutter.git
cd gestao-bovinos-flutter
flutter pub get
flutter run
```

Por padrão o app aponta para a **API de produção** (`api.gestaobovinos.com.br`). Para testar contra um backend local (ver `backend/README.md` para subir), rode:

```bash
flutter run --dart-define=USAR_BACKEND_LOCAL=true
```

No VS Code: selecione o dispositivo na barra de status (canto inferior direito) e pressione **F5**.

### Backend

```bash
cd backend
npm install
cp .env.example .env   # ajuste JWT_ACCESS_SECRET e demais chaves
docker compose up -d   # sobe o Postgres local
npm run prisma:migrate
npm run dev
```

Detalhes completos (testes, deploy, variáveis) em [`backend/README.md`](backend/README.md).

### Site/painel web

```bash
cd web
npm install
npm run dev
```

Detalhes em [`web/README.md`](web/README.md).

---

## Testes

### App Flutter

Testes unitários para modelos, repositórios, sincronização (Outbox, PollingSync) e cliente HTTP, usando um banco SQLite **em memória** (sem depender de dispositivo).

```bash
flutter test
```

### Backend

```bash
cd backend
npm test
```

---

## Variáveis sensíveis

Nenhum arquivo `.env` ou credencial vai commitado no repositório (`.gitignore` cobre `.env`, `google-services.json`, etc. em todas as três partes). Use os respectivos `.env.example` (`backend/.env.example`) como referência do que configurar.

| Arquivo | Por que não está no repo |
|---|---|
| `android/app/google-services.json` | Credenciais do Firebase Android (usado só para relatório de crash — Crashlytics) |
| `ios/Runner/GoogleService-Info.plist` | Credenciais do Firebase iOS |
| `backend/.env` | Segredos do backend (JWT, banco, Resend, Cloudinary) |
| `web/.env.local` | Configuração do painel web |
