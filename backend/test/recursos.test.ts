import { afterEach, describe, expect, it } from "vitest";
import request from "supertest";
import { app } from "./helpers/app";
import { limparBanco } from "./helpers/banco";
import { registrarUsuario } from "./helpers/usuarios";

afterEach(async () => {
  await limparBanco();
});

describe("Invernadas", () => {
  it("cria, lista, atualiza e exclui uma invernada", async () => {
    const { headers, fazendaId } = await registrarUsuario();
    const base = `/api/v1/fazendas/${fazendaId}/invernadas`;

    const criada = await request(app)
      .post(base)
      .set(headers)
      .send({ descricao: "Piquete 1", hectares: 10 })
      .expect(201);
    const invernadaId = criada.body.data.id;

    const lista = await request(app).get(base).set(headers).expect(200);
    expect(lista.body.data.paginacao.total).toBe(1);

    await request(app)
      .put(`${base}/${invernadaId}`)
      .set(headers)
      .send({ descricao: "Piquete 1 Atualizado" })
      .expect(200);

    await request(app).delete(`${base}/${invernadaId}`).set(headers).expect(204);

    const buscada = await request(app).get(`${base}/${invernadaId}`).set(headers);
    expect(buscada.status).toBe(404);
  });

  it("isola dados entre fazendas de usuarios diferentes (403)", async () => {
    const dono = await registrarUsuario();
    const outro = await registrarUsuario();

    const resposta = await request(app)
      .get(`/api/v1/fazendas/${dono.fazendaId}/invernadas`)
      .set(outro.headers);
    expect(resposta.status).toBe(403);
  });
});

describe("Bovinos", () => {
  async function criarInvernada(headers: { Authorization: string }, fazendaId: string) {
    const resposta = await request(app)
      .post(`/api/v1/fazendas/${fazendaId}/invernadas`)
      .set(headers)
      .send({ descricao: "Invernada base" })
      .expect(201);
    return resposta.body.data.id as string;
  }

  it("cria bovino, move de invernada e registra baixa", async () => {
    const { headers, fazendaId } = await registrarUsuario();
    const invernadaA = await criarInvernada(headers, fazendaId);
    const respInvB = await request(app)
      .post(`/api/v1/fazendas/${fazendaId}/invernadas`)
      .set(headers)
      .send({ descricao: "Invernada B" })
      .expect(201);
    const invernadaB = respInvB.body.data.id;

    const bovino = await request(app)
      .post(`/api/v1/fazendas/${fazendaId}/bovinos`)
      .set(headers)
      .send({ numeroBrinco: "BR-100", categoria: "Vaca", invernadaId: invernadaA })
      .expect(201);
    const bovinoId = bovino.body.data.id;

    const movimentacao = await request(app)
      .post(`/api/v1/fazendas/${fazendaId}/movimentacoes`)
      .set(headers)
      .send({ bovinoId, novaInvernadaId: invernadaB, data: "2026-07-31" })
      .expect(201);
    expect(movimentacao.body.data.invernadaAnteriorId).toBe(invernadaA);
    expect(movimentacao.body.data.novaInvernadaId).toBe(invernadaB);

    const bovinoAtualizado = await request(app)
      .get(`/api/v1/fazendas/${fazendaId}/bovinos/${bovinoId}`)
      .set(headers)
      .expect(200);
    expect(bovinoAtualizado.body.data.invernadaId).toBe(invernadaB);

    const baixa = await request(app)
      .patch(`/api/v1/fazendas/${fazendaId}/bovinos/${bovinoId}/baixa`)
      .set(headers)
      .send({ motivo: "Venda", dataBaixa: "2026-07-31" })
      .expect(200);
    expect(baixa.body.data.status).toBe("Baixado");

    const baixaRepetida = await request(app)
      .patch(`/api/v1/fazendas/${fazendaId}/bovinos/${bovinoId}/baixa`)
      .set(headers)
      .send({ motivo: "Venda", dataBaixa: "2026-07-31" });
    expect(baixaRepetida.status).toBe(409);
  });

  it("rejeita invernadaId de outra fazenda ao criar bovino (422)", async () => {
    const { headers, fazendaId } = await registrarUsuario();
    const resposta = await request(app)
      .post(`/api/v1/fazendas/${fazendaId}/bovinos`)
      .set(headers)
      .send({ numeroBrinco: "BR-200", categoria: "Touro", invernadaId: "00000000-0000-0000-0000-000000000000" });
    expect(resposta.status).toBe(422);
  });

  // Regressao: os clientes (app Flutter e site) mandam `null` explicito nos
  // campos opcionais vazios em vez de omitir a chave (diferente do Firestore,
  // que aceitava ambos) -- sem `.nullable()` no DTO, isso derrubava toda
  // atualizacao de um bovino com qualquer campo vazio com 422.
  it("aceita null explicito nos campos opcionais ao criar e atualizar bovino", async () => {
    const { headers, fazendaId } = await registrarUsuario();
    const base = `/api/v1/fazendas/${fazendaId}/bovinos`;

    const criado = await request(app)
      .post(base)
      .set(headers)
      .send({
        numeroBrinco: "BR-400",
        categoria: "Vaca",
        nomeAnimal: null,
        raca: null,
        pesoAtualKg: null,
        invernadaId: null,
        idMae: null,
        observacoes: null,
      })
      .expect(201);
    const bovinoId = criado.body.data.id;

    await request(app)
      .put(`${base}/${bovinoId}`)
      .set(headers)
      .send({ numeroBrinco: "BR-400", categoria: "Vaca", pesoAtualKg: null, observacoes: null })
      .expect(200);
  });

  it("aplica e remove o destaque colorido do bovino", async () => {
    const { headers, fazendaId } = await registrarUsuario();
    const base = `/api/v1/fazendas/${fazendaId}/bovinos`;

    const criado = await request(app)
      .post(base)
      .set(headers)
      .send({ numeroBrinco: "BR-500", categoria: "Novilha" })
      .expect(201);
    const bovinoId = criado.body.data.id;

    const destacado = await request(app)
      .put(`${base}/${bovinoId}`)
      .set(headers)
      .send({
        numeroBrinco: "BR-500",
        categoria: "Novilha",
        corDestaque: "amarelo",
        rotuloDestaque: "Vacina X - reforco",
      })
      .expect(200);
    expect(destacado.body.data.corDestaque).toBe("amarelo");
    expect(destacado.body.data.rotuloDestaque).toBe("Vacina X - reforco");

    const removido = await request(app)
      .put(`${base}/${bovinoId}`)
      .set(headers)
      .send({
        numeroBrinco: "BR-500",
        categoria: "Novilha",
        corDestaque: null,
        rotuloDestaque: null,
      })
      .expect(200);
    expect(removido.body.data.corDestaque).toBeNull();
    expect(removido.body.data.rotuloDestaque).toBeNull();
  });

  it("rejeita cor de destaque fora da paleta permitida (422)", async () => {
    const { headers, fazendaId } = await registrarUsuario();
    const resposta = await request(app)
      .post(`/api/v1/fazendas/${fazendaId}/bovinos`)
      .set(headers)
      .send({ numeroBrinco: "BR-501", categoria: "Novilha", corDestaque: "rosa-choque" });
    expect(resposta.status).toBe(422);
  });
});

describe("Eventos sanitarios", () => {
  it("cria um evento vinculado a um bovino e o lista", async () => {
    const { headers, fazendaId } = await registrarUsuario();
    const bovino = await request(app)
      .post(`/api/v1/fazendas/${fazendaId}/bovinos`)
      .set(headers)
      .send({ numeroBrinco: "BR-300", categoria: "Novilha" })
      .expect(201);
    const bovinoId = bovino.body.data.id;

    const evento = await request(app)
      .post(`/api/v1/fazendas/${fazendaId}/eventos-sanitarios`)
      .set(headers)
      .send({ tipo: "Vacinacao", bovinoIds: [bovinoId], produtoUtilizado: "Vacina X" })
      .expect(201);
    expect(evento.body.data.bovinos).toHaveLength(1);

    const lista = await request(app)
      .get(`/api/v1/fazendas/${fazendaId}/eventos-sanitarios`)
      .set(headers)
      .expect(200);
    expect(lista.body.data.paginacao.total).toBe(1);
  });
});
