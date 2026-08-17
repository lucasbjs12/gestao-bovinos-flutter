import request from "supertest";
import { afterEach, describe, expect, it } from "vitest";
import { app } from "./helpers/app";
import { limparBanco } from "./helpers/banco";
import { registrarUsuario } from "./helpers/usuarios";

afterEach(async () => {
  await limparBanco();
});

function cadastrarBovino(headers: Record<string, string>, fazendaId: string, brinco: string) {
  return request(app)
    .post(`/api/v1/fazendas/${fazendaId}/bovinos`)
    .set(headers)
    .send({ numeroBrinco: brinco, categoria: "Vaca" });
}

describe("Limite de animais do plano Gratuito", () => {
  it("permite cadastrar até 15 animais e bloqueia o 16º com 403", async () => {
    const { headers, fazendaId } = await registrarUsuario();

    for (let i = 1; i <= 15; i++) {
      const resposta = await cadastrarBovino(headers, fazendaId, `brinco-${i}`);
      expect(resposta.status).toBe(201);
    }

    const decimoSexto = await cadastrarBovino(headers, fazendaId, "brinco-16");
    expect(decimoSexto.status).toBe(403);
    expect(decimoSexto.body.error.code).toBe("limite_do_plano_atingido");

    // Os 15 já cadastrados continuam intactos -- só o próximo é bloqueado.
    const lista = await request(app)
      .get(`/api/v1/fazendas/${fazendaId}/bovinos?pageSize=50`)
      .set(headers);
    expect(lista.body.data.paginacao.total).toBe(15);
  });

  it("não conta bovinos baixados contra o limite", async () => {
    const { headers, fazendaId } = await registrarUsuario();

    for (let i = 1; i <= 15; i++) {
      await cadastrarBovino(headers, fazendaId, `b-${i}`).expect(201);
    }

    // Bloqueado com os 15 ativos.
    await cadastrarBovino(headers, fazendaId, "b-16").expect(403);

    // Dá baixa num deles -- volta a ter espaço pro próximo cadastro.
    const lista = await request(app)
      .get(`/api/v1/fazendas/${fazendaId}/bovinos?pageSize=50`)
      .set(headers);
    const primeiroId = lista.body.data.itens[0].id;
    await request(app)
      .patch(`/api/v1/fazendas/${fazendaId}/bovinos/${primeiroId}/baixa`)
      .set(headers)
      .send({ motivo: "Venda", dataBaixa: "2026-01-01" })
      .expect(200);

    const agora = await cadastrarBovino(headers, fazendaId, "b-17");
    expect(agora.status).toBe(201);
  });
});
