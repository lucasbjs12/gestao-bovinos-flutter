/**
 * Spec OpenAPI 3.0 escrita a mao (nao gerada por JSDoc) para bater exatamente
 * com o que as rotas/DTOs fazem de verdade. Atualizar aqui ao mudar uma rota.
 */
export const openApiDocument = {
  openapi: "3.0.3",
  info: {
    title: "GestaoBovinosApp API",
    version: "0.1.0",
    description:
      "API REST propria do GestaoBovinosApp (substitui Firebase Auth + Firestore). " +
      "Todas as respostas seguem o formato { success, message, data } no sucesso e " +
      "{ success: false, message, error } no erro.",
  },
  servers: [
    { url: "http://localhost:3000/api/v1", description: "Desenvolvimento local" },
  ],
  security: [{ bearerAuth: [] }],
  tags: [
    { name: "Auth" },
    { name: "Invernadas" },
    { name: "Bovinos" },
    { name: "EventosSanitarios" },
    { name: "Movimentacoes" },
    { name: "Atividades" },
    { name: "Convites" },
    { name: "Membros" },
    { name: "Uploads" },
    { name: "Admin" },
  ],
  components: {
    securitySchemes: {
      bearerAuth: { type: "http", scheme: "bearer", bearerFormat: "JWT" },
    },
    parameters: {
      FazendaId: {
        name: "fazendaId",
        in: "path",
        required: true,
        schema: { type: "string", format: "uuid" },
      },
      Id: {
        name: "id",
        in: "path",
        required: true,
        schema: { type: "string", format: "uuid" },
      },
      Page: { name: "page", in: "query", schema: { type: "integer", minimum: 1, default: 1 } },
      PageSize: {
        name: "pageSize",
        in: "query",
        schema: { type: "integer", minimum: 1, maximum: 100, default: 30 },
      },
      Busca: { name: "busca", in: "query", schema: { type: "string" } },
    },
    responses: {
      NaoAutorizado: { description: "Token ausente, invalido ou expirado", content: { "application/json": { schema: { $ref: "#/components/schemas/ErroResposta" } } } },
      Proibido: { description: "Sem permissao para esta acao", content: { "application/json": { schema: { $ref: "#/components/schemas/ErroResposta" } } } },
      NaoEncontrado: { description: "Recurso nao encontrado", content: { "application/json": { schema: { $ref: "#/components/schemas/ErroResposta" } } } },
      Conflito: { description: "Conflito com o estado atual do recurso", content: { "application/json": { schema: { $ref: "#/components/schemas/ErroResposta" } } } },
      ErroValidacao: { description: "Dados invalidos", content: { "application/json": { schema: { $ref: "#/components/schemas/ErroResposta" } } } },
    },
    schemas: {
      ErroResposta: {
        type: "object",
        properties: {
          success: { type: "boolean", example: false },
          message: { type: "string" },
          error: { type: "object", nullable: true },
        },
      },
      Paginacao: {
        type: "object",
        properties: {
          page: { type: "integer" },
          pageSize: { type: "integer" },
          total: { type: "integer" },
          totalPaginas: { type: "integer" },
        },
      },
      Usuario: {
        type: "object",
        properties: {
          id: { type: "string", format: "uuid" },
          nome: { type: "string" },
          email: { type: "string", format: "email" },
          isAdmin: { type: "boolean" },
          statusAssinatura: { type: "string", enum: ["pendente", "ativo", "bloqueado", "vencido"] },
        },
      },
      Fazenda: {
        type: "object",
        properties: {
          id: { type: "string", format: "uuid" },
          donoId: { type: "string", format: "uuid" },
          nome: { type: "string" },
          criadoEm: { type: "string", format: "date-time" },
        },
      },
      RegistroInput: {
        type: "object",
        required: ["nome", "email", "senha"],
        properties: {
          nome: { type: "string", minLength: 2 },
          email: { type: "string", format: "email" },
          senha: { type: "string", minLength: 8 },
          nomeFazenda: { type: "string", minLength: 2 },
        },
      },
      LoginInput: {
        type: "object",
        required: ["email", "senha"],
        properties: { email: { type: "string", format: "email" }, senha: { type: "string" } },
      },
      RefreshInput: {
        type: "object",
        required: ["refreshToken"],
        properties: { refreshToken: { type: "string" } },
      },
      TokensResposta: {
        type: "object",
        properties: {
          usuario: { $ref: "#/components/schemas/Usuario" },
          accessToken: { type: "string", description: "JWT, expira em ~15min" },
          refreshToken: { type: "string", description: "Opaco, rotaciona a cada uso" },
        },
      },
      Invernada: {
        type: "object",
        properties: {
          id: { type: "string", format: "uuid" },
          fazendaId: { type: "string", format: "uuid" },
          descricao: { type: "string" },
          hectares: { type: "number", nullable: true },
          urlFoto: { type: "string", nullable: true },
          observacoes: { type: "string", nullable: true },
          atualizadoEm: { type: "string", format: "date-time" },
          _count: { type: "object", properties: { bovinos: { type: "integer" } } },
        },
      },
      CriarInvernadaInput: {
        type: "object",
        required: ["descricao"],
        properties: {
          descricao: { type: "string", minLength: 1 },
          hectares: { type: "number" },
          urlFoto: { type: "string", format: "uri" },
          observacoes: { type: "string" },
        },
      },
      AtualizarInvernadaInput: { allOf: [{ $ref: "#/components/schemas/CriarInvernadaInput" }], description: "Todos os campos opcionais" },
      CategoriaBovino: { type: "string", enum: ["Vaca", "Novilha", "Terneira", "Terneiro", "Novilho", "Touro", "Boi"] },
      MotivoBaixa: { type: "string", enum: ["Morte", "Venda", "Furto", "Outros"] },
      Bovino: {
        type: "object",
        properties: {
          id: { type: "string", format: "uuid" },
          fazendaId: { type: "string", format: "uuid" },
          nomeAnimal: { type: "string", nullable: true },
          codigoEpc: { type: "string", nullable: true },
          codigoInterno: { type: "string", nullable: true },
          numeroBrinco: { type: "string" },
          raca: { type: "string", nullable: true },
          dataNascimento: { type: "string", format: "date", nullable: true },
          pesoAtualKg: { type: "number", nullable: true },
          pelagem: { type: "string", nullable: true },
          categoria: { $ref: "#/components/schemas/CategoriaBovino" },
          status: { type: "string", example: "Ativo" },
          origem: { type: "string", nullable: true },
          observacoes: { type: "string", nullable: true },
          foto: { type: "string", nullable: true },
          invernadaId: { type: "string", format: "uuid", nullable: true },
          idMae: { type: "string", format: "uuid", nullable: true },
          estaDeCria: { type: "boolean" },
          atualizadoEm: { type: "string", format: "date-time" },
        },
      },
      CriarBovinoInput: {
        type: "object",
        required: ["numeroBrinco", "categoria"],
        properties: {
          nomeAnimal: { type: "string" },
          codigoEpc: { type: "string" },
          codigoInterno: { type: "string" },
          numeroBrinco: { type: "string", minLength: 1 },
          raca: { type: "string" },
          dataNascimento: { type: "string", format: "date" },
          pesoAtualKg: { type: "number" },
          pelagem: { type: "string" },
          categoria: { $ref: "#/components/schemas/CategoriaBovino" },
          origem: { type: "string" },
          observacoes: { type: "string" },
          foto: { type: "string", format: "uri" },
          invernadaId: { type: "string", format: "uuid", description: "Precisa pertencer a mesma fazenda" },
          idMae: { type: "string", format: "uuid", description: "Precisa pertencer a mesma fazenda" },
          estaDeCria: { type: "boolean", default: false },
        },
      },
      AtualizarBovinoInput: { allOf: [{ $ref: "#/components/schemas/CriarBovinoInput" }], description: "Todos os campos opcionais" },
      RegistrarBaixaInput: {
        type: "object",
        required: ["motivo", "dataBaixa"],
        properties: {
          motivo: { $ref: "#/components/schemas/MotivoBaixa" },
          observacoes: { type: "string" },
          dataBaixa: { type: "string", format: "date" },
        },
      },
      TipoEventoSanitario: { type: "string", enum: ["Vacinacao", "Vermifugacao", "Medicacao", "Castracao", "Banho", "Outros"] },
      EventoSanitario: {
        type: "object",
        properties: {
          id: { type: "string", format: "uuid" },
          fazendaId: { type: "string", format: "uuid" },
          tipo: { $ref: "#/components/schemas/TipoEventoSanitario" },
          dataEvento: { type: "string", format: "date", nullable: true },
          invernadaId: { type: "string", format: "uuid", nullable: true },
          produtoUtilizado: { type: "string", nullable: true },
          dosagem: { type: "string", nullable: true },
          responsavel: { type: "string", nullable: true },
          observacoes: { type: "string", nullable: true },
          bovinos: { type: "array", items: { type: "object" } },
        },
      },
      CriarEventoSanitarioInput: {
        type: "object",
        required: ["tipo", "bovinoIds"],
        properties: {
          tipo: { $ref: "#/components/schemas/TipoEventoSanitario" },
          dataEvento: { type: "string", format: "date" },
          invernadaId: { type: "string", format: "uuid" },
          produtoUtilizado: { type: "string" },
          dosagem: { type: "string" },
          responsavel: { type: "string" },
          observacoes: { type: "string" },
          bovinoIds: { type: "array", items: { type: "string", format: "uuid" }, minItems: 1 },
        },
      },
      AtualizarEventoSanitarioInput: { allOf: [{ $ref: "#/components/schemas/CriarEventoSanitarioInput" }], description: "Todos os campos opcionais" },
      MovimentacaoInvernada: {
        type: "object",
        properties: {
          id: { type: "string", format: "uuid" },
          fazendaId: { type: "string", format: "uuid" },
          bovinoId: { type: "string", format: "uuid" },
          data: { type: "string", format: "date" },
          invernadaAnteriorId: { type: "string", format: "uuid", nullable: true },
          novaInvernadaId: { type: "string", format: "uuid" },
          responsavel: { type: "string", nullable: true },
          observacoes: { type: "string", nullable: true },
        },
      },
      CriarMovimentacaoInput: {
        type: "object",
        required: ["bovinoId", "novaInvernadaId", "data"],
        properties: {
          bovinoId: { type: "string", format: "uuid" },
          novaInvernadaId: { type: "string", format: "uuid" },
          data: { type: "string", format: "date" },
          responsavel: { type: "string" },
          observacoes: { type: "string" },
        },
      },
      Atividade: {
        type: "object",
        properties: {
          id: { type: "string", format: "uuid" },
          fazendaId: { type: "string", format: "uuid" },
          autorId: { type: "string", format: "uuid" },
          autorNome: { type: "string", nullable: true },
          acao: { type: "string", example: "bovino_salvo" },
          descricao: { type: "string" },
          criadoEm: { type: "string", format: "date-time" },
        },
      },
      Convite: {
        type: "object",
        properties: {
          codigo: { type: "string", example: "BOV-4F7K9X" },
          fazendaId: { type: "string", format: "uuid" },
          papel: { type: "string", enum: ["dono", "convidado"] },
          expiraEm: { type: "string", format: "date-time" },
          usado: { type: "boolean" },
        },
      },
      Membro: {
        type: "object",
        properties: {
          fazendaId: { type: "string", format: "uuid" },
          usuarioId: { type: "string", format: "uuid" },
          papel: { type: "string", enum: ["dono", "convidado"] },
          nome: { type: "string", nullable: true },
          desde: { type: "string", format: "date-time" },
          usuario: { type: "object", properties: { id: { type: "string" }, nome: { type: "string" }, email: { type: "string" } } },
        },
      },
      AssinarUploadResposta: {
        type: "object",
        properties: {
          cloudName: { type: "string" },
          apiKey: { type: "string" },
          timestamp: { type: "integer" },
          folder: { type: "string" },
          signature: { type: "string" },
          uploadUrl: { type: "string", format: "uri" },
        },
      },
      AtualizarAssinaturaInput: {
        type: "object",
        required: ["statusAssinatura"],
        properties: {
          statusAssinatura: { type: "string", enum: ["pendente", "ativo", "bloqueado", "vencido"] },
          plano: { type: "string" },
          vencimento: { type: "string", format: "date-time" },
        },
      },
    },
  },
  paths: {
    "/auth/registro": {
      post: {
        tags: ["Auth"],
        summary: "Cria usuario, fazenda propria e membro dono numa transaction",
        security: [],
        requestBody: { required: true, content: { "application/json": { schema: { $ref: "#/components/schemas/RegistroInput" } } } },
        responses: {
          "201": { description: "Conta criada", content: { "application/json": { schema: { allOf: [{ $ref: "#/components/schemas/TokensResposta" }, { type: "object", properties: { fazenda: { $ref: "#/components/schemas/Fazenda" } } }] } } } },
          "409": { $ref: "#/components/responses/Conflito" },
          "422": { $ref: "#/components/responses/ErroValidacao" },
        },
      },
    },
    "/auth/login": {
      post: {
        tags: ["Auth"],
        summary: "Login com e-mail e senha",
        security: [],
        requestBody: { required: true, content: { "application/json": { schema: { $ref: "#/components/schemas/LoginInput" } } } },
        responses: {
          "200": { description: "Login realizado", content: { "application/json": { schema: { $ref: "#/components/schemas/TokensResposta" } } } },
          "401": { $ref: "#/components/responses/NaoAutorizado" },
        },
      },
    },
    "/auth/refresh": {
      post: {
        tags: ["Auth"],
        summary: "Rotaciona o refresh token (revoga o antigo, emite um par novo)",
        security: [],
        requestBody: { required: true, content: { "application/json": { schema: { $ref: "#/components/schemas/RefreshInput" } } } },
        responses: {
          "200": { description: "Token renovado", content: { "application/json": { schema: { $ref: "#/components/schemas/TokensResposta" } } } },
          "401": { $ref: "#/components/responses/NaoAutorizado" },
        },
      },
    },
    "/auth/logout": {
      post: {
        tags: ["Auth"],
        summary: "Revoga o refresh token informado",
        security: [],
        requestBody: { required: true, content: { "application/json": { schema: { $ref: "#/components/schemas/RefreshInput" } } } },
        responses: { "200": { description: "Logout realizado" } },
      },
    },
    "/auth/me": {
      get: {
        tags: ["Auth"],
        summary: "Dados do usuario autenticado + fazenda propria",
        responses: {
          "200": { description: "OK", content: { "application/json": { schema: { type: "object", properties: { usuario: { $ref: "#/components/schemas/Usuario" }, fazendaPropria: { $ref: "#/components/schemas/Fazenda" } } } } } },
          "401": { $ref: "#/components/responses/NaoAutorizado" },
        },
      },
    },
    "/convites/{codigo}": {
      get: {
        tags: ["Convites"],
        summary: "Valida um convite (nao exige ja ser membro da fazenda)",
        parameters: [{ name: "codigo", in: "path", required: true, schema: { type: "string", example: "BOV-4F7K9X" } }],
        responses: {
          "200": { description: "OK", content: { "application/json": { schema: { allOf: [{ $ref: "#/components/schemas/Convite" }, { type: "object", properties: { valido: { type: "boolean" }, fazenda: { $ref: "#/components/schemas/Fazenda" } } }] } } } },
          "404": { $ref: "#/components/responses/NaoEncontrado" },
        },
      },
    },
    "/convites/{codigo}/aceitar": {
      post: {
        tags: ["Convites"],
        summary: "Aceita o convite: cria o Membro (papel convidado) e marca o convite como usado",
        parameters: [{ name: "codigo", in: "path", required: true, schema: { type: "string" } }],
        responses: {
          "200": { description: "Convite aceito" },
          "404": { $ref: "#/components/responses/NaoEncontrado" },
          "409": { description: "Convite ja usado/expirado, ou usuario ja e dono/membro" },
        },
      },
    },
    "/admin/usuarios": {
      get: {
        tags: ["Admin"],
        summary: "Lista usuarios (restrito a isAdmin)",
        parameters: [{ $ref: "#/components/parameters/Page" }, { $ref: "#/components/parameters/PageSize" }, { $ref: "#/components/parameters/Busca" }],
        responses: {
          "200": { description: "OK" },
          "403": { $ref: "#/components/responses/Proibido" },
        },
      },
    },
    "/admin/usuarios/{id}/assinatura": {
      patch: {
        tags: ["Admin"],
        summary: "Atualiza status/plano/vencimento da assinatura de um usuario (restrito a isAdmin)",
        parameters: [{ $ref: "#/components/parameters/Id" }],
        requestBody: { required: true, content: { "application/json": { schema: { $ref: "#/components/schemas/AtualizarAssinaturaInput" } } } },
        responses: {
          "200": { description: "Atualizado" },
          "403": { $ref: "#/components/responses/Proibido" },
          "404": { $ref: "#/components/responses/NaoEncontrado" },
        },
      },
    },
    "/fazendas/{fazendaId}/invernadas": {
      get: {
        tags: ["Invernadas"],
        summary: "Lista invernadas (paginado, busca por descricao)",
        parameters: [{ $ref: "#/components/parameters/FazendaId" }, { $ref: "#/components/parameters/Page" }, { $ref: "#/components/parameters/PageSize" }, { $ref: "#/components/parameters/Busca" }],
        responses: { "200": { description: "OK" }, "403": { $ref: "#/components/responses/Proibido" } },
      },
      post: {
        tags: ["Invernadas"],
        summary: "Cria invernada (dono ou convidado)",
        parameters: [{ $ref: "#/components/parameters/FazendaId" }],
        requestBody: { required: true, content: { "application/json": { schema: { $ref: "#/components/schemas/CriarInvernadaInput" } } } },
        responses: { "201": { description: "Criada", content: { "application/json": { schema: { $ref: "#/components/schemas/Invernada" } } } }, "422": { $ref: "#/components/responses/ErroValidacao" } },
      },
    },
    "/fazendas/{fazendaId}/invernadas/{id}": {
      get: {
        tags: ["Invernadas"],
        summary: "Busca invernada por id",
        parameters: [{ $ref: "#/components/parameters/FazendaId" }, { $ref: "#/components/parameters/Id" }],
        responses: { "200": { description: "OK", content: { "application/json": { schema: { $ref: "#/components/schemas/Invernada" } } } }, "404": { $ref: "#/components/responses/NaoEncontrado" } },
      },
      put: {
        tags: ["Invernadas"],
        summary: "Atualiza invernada (dono ou convidado)",
        parameters: [{ $ref: "#/components/parameters/FazendaId" }, { $ref: "#/components/parameters/Id" }],
        requestBody: { required: true, content: { "application/json": { schema: { $ref: "#/components/schemas/AtualizarInvernadaInput" } } } },
        responses: { "200": { description: "Atualizada" }, "404": { $ref: "#/components/responses/NaoEncontrado" } },
      },
      delete: {
        tags: ["Invernadas"],
        summary: "Exclui invernada (so dono)",
        parameters: [{ $ref: "#/components/parameters/FazendaId" }, { $ref: "#/components/parameters/Id" }],
        responses: { "204": { description: "Excluida" }, "403": { $ref: "#/components/responses/Proibido" }, "404": { $ref: "#/components/responses/NaoEncontrado" } },
      },
    },
    "/fazendas/{fazendaId}/invernadas/{id}/movimentacoes": {
      get: {
        tags: ["Invernadas"],
        summary: "Historico de movimentacoes que entram ou saem desta invernada",
        parameters: [{ $ref: "#/components/parameters/FazendaId" }, { $ref: "#/components/parameters/Id" }, { $ref: "#/components/parameters/Page" }, { $ref: "#/components/parameters/PageSize" }],
        responses: { "200": { description: "OK" } },
      },
    },
    "/fazendas/{fazendaId}/bovinos": {
      get: {
        tags: ["Bovinos"],
        summary: "Lista bovinos (paginado, filtro por invernada/categoria, busca por brinco/nome, ordenacao)",
        parameters: [
          { $ref: "#/components/parameters/FazendaId" }, { $ref: "#/components/parameters/Page" }, { $ref: "#/components/parameters/PageSize" }, { $ref: "#/components/parameters/Busca" },
          { name: "invernadaId", in: "query", schema: { type: "string", format: "uuid" } },
          { name: "categoria", in: "query", schema: { $ref: "#/components/schemas/CategoriaBovino" } },
          { name: "ordenarPor", in: "query", schema: { type: "string", enum: ["brinco", "nome", "categoria", "peso"], default: "brinco" } },
        ],
        responses: { "200": { description: "OK" } },
      },
      post: {
        tags: ["Bovinos"],
        summary: "Cadastra bovino (dono ou convidado)",
        parameters: [{ $ref: "#/components/parameters/FazendaId" }],
        requestBody: { required: true, content: { "application/json": { schema: { $ref: "#/components/schemas/CriarBovinoInput" } } } },
        responses: { "201": { description: "Criado", content: { "application/json": { schema: { $ref: "#/components/schemas/Bovino" } } } }, "422": { $ref: "#/components/responses/ErroValidacao" } },
      },
    },
    "/fazendas/{fazendaId}/bovinos/{id}": {
      get: {
        tags: ["Bovinos"],
        summary: "Busca bovino por id (inclui invernada, mae e historico de baixas)",
        parameters: [{ $ref: "#/components/parameters/FazendaId" }, { $ref: "#/components/parameters/Id" }],
        responses: { "200": { description: "OK", content: { "application/json": { schema: { $ref: "#/components/schemas/Bovino" } } } }, "404": { $ref: "#/components/responses/NaoEncontrado" } },
      },
      put: {
        tags: ["Bovinos"],
        summary: "Atualiza bovino (dono ou convidado)",
        parameters: [{ $ref: "#/components/parameters/FazendaId" }, { $ref: "#/components/parameters/Id" }],
        requestBody: { required: true, content: { "application/json": { schema: { $ref: "#/components/schemas/AtualizarBovinoInput" } } } },
        responses: { "200": { description: "Atualizado" }, "404": { $ref: "#/components/responses/NaoEncontrado" } },
      },
      delete: {
        tags: ["Bovinos"],
        summary: "Exclui bovino (so dono)",
        parameters: [{ $ref: "#/components/parameters/FazendaId" }, { $ref: "#/components/parameters/Id" }],
        responses: { "204": { description: "Excluido" }, "403": { $ref: "#/components/responses/Proibido" } },
      },
    },
    "/fazendas/{fazendaId}/bovinos/{id}/baixa": {
      patch: {
        tags: ["Bovinos"],
        summary: "Registra baixa (morte/venda/furto/outros) e marca status = Baixado",
        parameters: [{ $ref: "#/components/parameters/FazendaId" }, { $ref: "#/components/parameters/Id" }],
        requestBody: { required: true, content: { "application/json": { schema: { $ref: "#/components/schemas/RegistrarBaixaInput" } } } },
        responses: { "200": { description: "Baixa registrada", content: { "application/json": { schema: { $ref: "#/components/schemas/Bovino" } } } }, "409": { description: "Animal ja esta baixado" } },
      },
    },
    "/fazendas/{fazendaId}/eventos-sanitarios": {
      get: {
        tags: ["EventosSanitarios"],
        summary: "Lista eventos sanitarios (paginado, filtro por tipo/invernada, busca)",
        parameters: [
          { $ref: "#/components/parameters/FazendaId" }, { $ref: "#/components/parameters/Page" }, { $ref: "#/components/parameters/PageSize" }, { $ref: "#/components/parameters/Busca" },
          { name: "tipo", in: "query", schema: { $ref: "#/components/schemas/TipoEventoSanitario" } },
          { name: "invernadaId", in: "query", schema: { type: "string", format: "uuid" } },
        ],
        responses: { "200": { description: "OK" } },
      },
      post: {
        tags: ["EventosSanitarios"],
        summary: "Registra evento sanitario para um ou mais bovinos",
        parameters: [{ $ref: "#/components/parameters/FazendaId" }],
        requestBody: { required: true, content: { "application/json": { schema: { $ref: "#/components/schemas/CriarEventoSanitarioInput" } } } },
        responses: { "201": { description: "Criado", content: { "application/json": { schema: { $ref: "#/components/schemas/EventoSanitario" } } } }, "422": { $ref: "#/components/responses/ErroValidacao" } },
      },
    },
    "/fazendas/{fazendaId}/eventos-sanitarios/{id}": {
      get: {
        tags: ["EventosSanitarios"],
        summary: "Busca evento sanitario por id",
        parameters: [{ $ref: "#/components/parameters/FazendaId" }, { $ref: "#/components/parameters/Id" }],
        responses: { "200": { description: "OK", content: { "application/json": { schema: { $ref: "#/components/schemas/EventoSanitario" } } } }, "404": { $ref: "#/components/responses/NaoEncontrado" } },
      },
      put: {
        tags: ["EventosSanitarios"],
        summary: "Atualiza evento sanitario (bovinoIds, se enviado, substitui o conjunto de animais)",
        parameters: [{ $ref: "#/components/parameters/FazendaId" }, { $ref: "#/components/parameters/Id" }],
        requestBody: { required: true, content: { "application/json": { schema: { $ref: "#/components/schemas/AtualizarEventoSanitarioInput" } } } },
        responses: { "200": { description: "Atualizado" }, "404": { $ref: "#/components/responses/NaoEncontrado" } },
      },
      delete: {
        tags: ["EventosSanitarios"],
        summary: "Exclui evento sanitario (so dono)",
        parameters: [{ $ref: "#/components/parameters/FazendaId" }, { $ref: "#/components/parameters/Id" }],
        responses: { "204": { description: "Excluido" }, "403": { $ref: "#/components/responses/Proibido" } },
      },
    },
    "/fazendas/{fazendaId}/movimentacoes": {
      post: {
        tags: ["Movimentacoes"],
        summary: "Move um bovino para outra invernada (atualiza bovino.invernadaId e registra o historico)",
        parameters: [{ $ref: "#/components/parameters/FazendaId" }],
        requestBody: { required: true, content: { "application/json": { schema: { $ref: "#/components/schemas/CriarMovimentacaoInput" } } } },
        responses: { "201": { description: "Registrada", content: { "application/json": { schema: { $ref: "#/components/schemas/MovimentacaoInvernada" } } } }, "422": { $ref: "#/components/responses/ErroValidacao" } },
      },
    },
    "/fazendas/{fazendaId}/atividades": {
      get: {
        tags: ["Atividades"],
        summary: "Diario de atividades da fazenda (imutavel, so leitura)",
        parameters: [{ $ref: "#/components/parameters/FazendaId" }, { $ref: "#/components/parameters/Page" }, { $ref: "#/components/parameters/PageSize" }],
        responses: { "200": { description: "OK", content: { "application/json": { schema: { type: "array", items: { $ref: "#/components/schemas/Atividade" } } } } } },
      },
    },
    "/fazendas/{fazendaId}/convites": {
      get: {
        tags: ["Convites"],
        summary: "Lista convites da fazenda (so dono)",
        parameters: [{ $ref: "#/components/parameters/FazendaId" }],
        responses: { "200": { description: "OK" }, "403": { $ref: "#/components/responses/Proibido" } },
      },
      post: {
        tags: ["Convites"],
        summary: "Gera um convite (codigo BOV-XXXXXX, expira em 48h, so dono)",
        parameters: [{ $ref: "#/components/parameters/FazendaId" }],
        responses: { "201": { description: "Gerado", content: { "application/json": { schema: { $ref: "#/components/schemas/Convite" } } } }, "403": { $ref: "#/components/responses/Proibido" } },
      },
    },
    "/fazendas/{fazendaId}/membros": {
      get: {
        tags: ["Membros"],
        summary: "Lista membros da fazenda (qualquer membro)",
        parameters: [{ $ref: "#/components/parameters/FazendaId" }],
        responses: { "200": { description: "OK", content: { "application/json": { schema: { type: "array", items: { $ref: "#/components/schemas/Membro" } } } } } },
      },
    },
    "/fazendas/{fazendaId}/membros/{usuarioId}": {
      delete: {
        tags: ["Membros"],
        summary: "Remove um membro (so dono; nao remove o proprio dono)",
        parameters: [{ $ref: "#/components/parameters/FazendaId" }, { name: "usuarioId", in: "path", required: true, schema: { type: "string", format: "uuid" } }],
        responses: { "204": { description: "Removido" }, "403": { $ref: "#/components/responses/Proibido" }, "404": { $ref: "#/components/responses/NaoEncontrado" } },
      },
    },
    "/fazendas/{fazendaId}/uploads/assinar": {
      post: {
        tags: ["Uploads"],
        summary: "Gera payload de upload assinado para a Cloudinary (evita expor o api_secret no app)",
        parameters: [
          { $ref: "#/components/parameters/FazendaId" },
          { name: "pasta", in: "query", schema: { type: "string", enum: ["bovinos", "invernadas"] } },
        ],
        responses: {
          "200": { description: "OK", content: { "application/json": { schema: { $ref: "#/components/schemas/AssinarUploadResposta" } } } },
          "503": { description: "CLOUDINARY_* nao configurado neste ambiente" },
        },
      },
    },
  },
};
