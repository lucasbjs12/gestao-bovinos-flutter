import request from "supertest";
import { afterEach, describe, expect, it } from "vitest";
import { app } from "./helpers/app";
import { limparBanco } from "./helpers/banco";
import { registrarUsuario } from "./helpers/usuarios";

afterEach(async () => {
  await limparBanco();
});

describe("GET /planos", () => {
  it("lista os planos ativos, incluindo o Grátis", async () => {
    const { headers } = await registrarUsuario();

    const resposta = await request(app).get("/api/v1/planos").set(headers).expect(200);

    const slugs = resposta.body.data.map((p: { slug: string }) => p.slug);
    expect(slugs).toContain("gratuito");
    expect(slugs).toContain("produtor");
    expect(resposta.body.data.length).toBeGreaterThanOrEqual(9);
  });

  it("rejeita sem autenticação", async () => {
    await request(app).get("/api/v1/planos").expect(401);
  });
});

describe("GET /fazendas/:id/assinatura", () => {
  it("usuário novo nasce no plano Gratuito com limite de 15", async () => {
    const { headers, fazendaId } = await registrarUsuario();

    const resposta = await request(app)
      .get(`/api/v1/fazendas/${fazendaId}/assinatura`)
      .set(headers)
      .expect(200);

    expect(resposta.body.data.status).toBe("gratuito");
    expect(resposta.body.data.limiteAnimaisAtual).toBe(15);
    expect(resposta.body.data.contagemAnimais).toBe(0);
  });
});
