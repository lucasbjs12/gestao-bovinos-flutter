# Gestão de Bovinos — App Flutter

Aplicativo mobile de **gestão de rebanho bovino** desenvolvido em Flutter. Permite cadastrar e acompanhar animais, invernadas, eventos sanitários (vacinação, vermifugação, medicação etc.) e baixas, com sincronização em nuvem via Firebase e funcionamento offline via banco local SQLite.

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

### Outros
- Leitura de RFID
- Histórico de animais baixados com filtro por motivo e opção de reativação
- Sincronização em tempo real com Firebase Firestore
- Funcionamento offline: dados salvos localmente e sincronizados quando há conexão

---

## Tecnologias

| Camada | Tecnologia |
|---|---|
| Framework | Flutter 3.x |
| Linguagem | Dart 3.x |
| Estado | Provider |
| Banco local | SQLite via `sqflite` |
| Autenticação | Firebase Auth |
| Banco em nuvem | Cloud Firestore |
| Fotos | Cloudinary + fallback local |
| Testes | `flutter_test` + `sqflite_common_ffi` |

---

## Arquitetura

O projeto segue uma organização por **feature**, onde cada funcionalidade tem sua própria pasta contendo dados, lógica e apresentação:

```
lib/
├── core/
│   ├── db/              # Banco SQLite (AppDatabase — uma instância por usuário)
│   ├── routes/          # Rotas nomeadas
│   ├── storage/         # Cloudinary
│   ├── sync/            # Controle de estado de sincronização
│   ├── theme/           # Tema do app
│   └── utils/           # Utilitários (foto, etc.)
│
├── features/
│   ├── auth/            # Login, cadastro de fazenda, verificação de e-mail
│   ├── bovinos/         # Cadastro, detalhe, lista, baixa, animais baixados
│   ├── eventos_sanitarios/  # CRUD de eventos, rascunho
│   ├── home/            # Dashboard
│   ├── invernadas/      # Pastagens e movimentações
│   ├── perfil/          # Configurações do usuário
│   ├── rfid/            # Leitura de tags RFID
│   └── shell/           # Navegação principal (bottom nav)
│
├── sync/                # Sincronização inicial e em tempo real com Firestore
└── main.dart
```

### Fluxo de dados

```
UI (Screen)
   ↕ Provider (ChangeNotifier)
LocalRepository (SQLite)   ←→   RemoteRepository (Firestore)
```

- A **UI** lê estado do **Provider** e dispara ações
- O **Provider** orquestra chamadas ao banco local e atualiza o estado
- As operações de escrita também disparam um **fire-and-forget** para o Firestore via `RemoteRepository`
- Ao abrir o app, o `InitialSyncService` baixa todos os dados do Firestore para o SQLite
- O `RealtimeSyncService` ouve mudanças no Firestore e atualiza o SQLite em tempo real

---

## Como rodar

### Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) instalado (versão 3.x ou superior)
- Android Studio com um emulador configurado (ou dispositivo físico)
- Conta no [Firebase](https://firebase.google.com/) com projeto criado

### 1. Clone o repositório

```bash
git clone https://github.com/lucasbjs12/gestao-bovinos-flutter.git
cd gestao-bovinos-flutter
```

### 2. Configure o Firebase

O arquivo `android/app/google-services.json` **não está incluído** no repositório por segurança. Você precisa:

1. Acessar o [Console do Firebase](https://console.firebase.google.com/)
2. Criar (ou abrir) seu projeto
3. Adicionar um app Android com o package name `lucas.tcc.gestaobovinosapp`
4. Baixar o `google-services.json` e colocar em `android/app/`

Habilite no Firebase:
- **Authentication** → método E-mail/Senha
- **Firestore Database** → modo produção (configure as regras de segurança)

### 3. Configure o Cloudinary (opcional)

Para upload de fotos funcionar em nuvem, edite `lib/core/storage/cloudinary_service.dart` com suas credenciais. Se não configurar, as fotos ficam salvas apenas localmente no dispositivo.

### 4. Instale as dependências

```bash
flutter pub get
```

### 5. Execute

```bash
# Listar dispositivos disponíveis
flutter devices

# Rodar no emulador
flutter run

# Ou especificar o dispositivo
flutter run -d emulator-5554
```

No VS Code: selecione o dispositivo na barra de status (canto inferior direito) e pressione **F5**.

---

## Testes

O projeto tem testes unitários para os modelos e repositórios, usando um banco SQLite **em memória** (sem depender de um dispositivo).

```bash
flutter test
```

Arquivos de teste em `test/`:
- `bovino_model_test.dart` — serialização e copyWith do modelo Bovino
- `bovino_repository_test.dart` — CRUD, filtros e paginação
- `evento_sanitario_repository_test.dart` — CRUD, filtros e ordenação de eventos

---

## Variáveis sensíveis

| Arquivo | Por que não está no repo |
|---|---|
| `android/app/google-services.json` | Credenciais do Firebase Android |
| `ios/Runner/GoogleService-Info.plist` | Credenciais do Firebase iOS |

Para projetos **privados**, você pode remover essas entradas do `.gitignore` e commitar os arquivos com segurança.

---

## Licença

Projeto acadêmico — uso livre para fins educacionais.
