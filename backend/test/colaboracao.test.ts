import { afterEach, describe, expect, it } from "vitest";
import request from "supertest";
import { app } from "./helpers/app";
import { limparBanco } from "./helpers/banco";
import { registrarUsuario } from "./helpers/usuarios";

afterEach(async () => {
  await limparBanco();
});

describe("Convites e membros (RBAC dono vs convidado)", () => {
  it("fluxo completo: gerar convite, aceitar, RBAC do convidado e remocao", async () => {
    const dono = await registrarUsuario({ nomeFazenda: "Fazenda Colaborativa" });
    const convidado = await registrarUsuario();

    const convite = await request(app)
      .post(`/api/v1/fazendas/${dono.fazendaId}/convites`)
      .set(dono.headers)
      .expect(201);
    const codigo = convite.body.data.codigo;

    const validacao = await request(app)
      .get(`/api/v1/convites/${codigo}`)
      .set(convidado.headers)
      .expect(200);
    expect(validacao.body.data.valido).toBe(true);

    const aceite = await request(app)
      .post(`/api/v1/convites/${codigo}/aceitar`)
      .set(convidado.headers)
      .expect(200);
    expect(aceite.body.data.membro.papel).toBe("convidado");

    // Convidado consegue criar recursos na fazenda do dono.
    const invernada = await request(app)
      .post(`/api/v1/fazendas/${dono.fazendaId}/invernadas`)
      .set(convidado.headers)
      .send({ descricao: "Invernada do convidado" })
      .expect(201);

    // Mas nao consegue excluir (so dono).
    const tentativaExcluir = await request(app)
      .delete(`/api/v1/fazendas/${dono.fazendaId}/invernadas/${invernada.body.data.id}`)
      .set(convidado.headers);
    expect(tentativaExcluir.status).toBe(403);

    // Nem gerar outro convite.
    const tentativaConvite = await request(app)
      .post(`/api/v1/fazendas/${dono.fazendaId}/convites`)
      .set(convidado.headers);
    expect(tentativaConvite.status).toBe(403);

    // Reuso do convite ja aceito falha.
    const reuso = await request(app)
      .post(`/api/v1/convites/${codigo}/aceitar`)
      .set(convidado.headers);
    expect(reuso.status).toBe(409);

    // Dono ve o convidado na lista de membros.
    const membros = await request(app)
      .get(`/api/v1/fazendas/${dono.fazendaId}/membros`)
      .set(dono.headers)
      .expect(200);
    expect(membros.body.data).toHaveLength(2);

    // Dono remove o convidado -- que perde o acesso na sequencia.
    await request(app)
      .delete(`/api/v1/fazendas/${dono.fazendaId}/membros/${convidado.usuarioId}`)
      .set(dono.headers)
      .expect(204);

    const semAcesso = await request(app)
      .get(`/api/v1/fazendas/${dono.fazendaId}/bovinos`)
      .set(convidado.headers);
    expect(semAcesso.status).toBe(403);
  });

  it("diario de atividades registra as acoes da fazenda", async () => {
    const { headers, fazendaId } = await registrarUsuario();
    await request(app)
      .post(`/api/v1/fazendas/${fazendaId}/invernadas`)
      .set(headers)
      .send({ descricao: "Piquete registrado" })
      .expect(201);

    const atividades = await request(app)
      .get(`/api/v1/fazendas/${fazendaId}/atividades`)
      .set(headers)
      .expect(200);

    expect(atividades.body.data.paginacao.total).toBeGreaterThanOrEqual(1);
    expect(atividades.body.data.itens[0].acao).toBe("invernada_salva");
  });
});

describe("Painel admin", () => {
  it("usuario comum nao acessa rotas de admin (403)", async () => {
    const { headers } = await registrarUsuario();
    const resposta = await request(app).get("/api/v1/admin/usuarios").set(headers);
    expect(resposta.status).toBe(403);
  });
});
