import request from "supertest";
import { afterEach, describe, expect, it } from "vitest";
import { app } from "./helpers/app";
import { limparBanco } from "./helpers/banco";
import { registrarUsuario } from "./helpers/usuarios";
import { prisma } from "../src/config/prisma";

afterEach(async () => {
  await limparBanco();
});

async function tornarAdminEFazerLogin(usuarioId: string, email: string, senha: string) {
  await prisma.usuario.update({ where: { id: usuarioId }, data: { isAdmin: true } });
  // isAdmin vai dentro do JWT -- só um novo login pega o valor atualizado.
  const resposta = await request(app)
    .post("/api/v1/auth/login")
    .send({ email, senha })
    .expect(200);
  return { Authorization: `Bearer ${resposta.body.data.accessToken}` };
}

async function buscarPlanoProdutorMensal() {
  return prisma.plano.findFirstOrThrow({ where: { slug: "produtor", periodicidade: "mensal" } });
}

describe("POST /admin/usuarios/:id/assinatura/ativar-plano", () => {
  it("admin ativa manualmente um plano pago pra outro usuário", async () => {
    const admin = await registrarUsuario({ email: "admin@example.com", senha: "senhaDeTeste123" });
    const alvo = await registrarUsuario();
    const headersAdmin = await tornarAdminEFazerLogin(
      admin.usuarioId,
      "admin@example.com",
      "senhaDeTeste123",
    );
    const plano = await buscarPlanoProdutorMensal();

    const resposta = await request(app)
      .post(`/api/v1/admin/usuarios/${alvo.usuarioId}/assinatura/ativar-plano`)
      .set(headersAdmin)
      .send({ planoId: plano.id, proximaCobranca: "2027-01-01" })
      .expect(200);

    expect(resposta.body.data.status).toBe("ativo");
    expect(resposta.body.data.limiteAnimaisAtual).toBe(plano.limiteAnimais);

    // Reflete pro próprio usuário também, não só na resposta do admin.
    const assinaturaDoAlvo = await request(app)
      .get(`/api/v1/fazendas/${alvo.fazendaId}/assinatura`)
      .set(alvo.headers)
      .expect(200);
    expect(assinaturaDoAlvo.body.data.status).toBe("ativo");
    expect(assinaturaDoAlvo.body.data.plano.slug).toBe("produtor");
  });

  it("usuário comum (não-admin) não consegue ativar plano de outro", async () => {
    const naoAdmin = await registrarUsuario();
    const alvo = await registrarUsuario();
    const plano = await buscarPlanoProdutorMensal();

    await request(app)
      .post(`/api/v1/admin/usuarios/${alvo.usuarioId}/assinatura/ativar-plano`)
      .set(naoAdmin.headers)
      .send({ planoId: plano.id, proximaCobranca: "2027-01-01" })
      .expect(403);
  });
});

describe("DELETE /admin/usuarios/:id", () => {
  it("admin apaga a conta de outro usuário", async () => {
    const admin = await registrarUsuario({ email: "admin2@example.com", senha: "senhaDeTeste123" });
    const alvo = await registrarUsuario();
    const headersAdmin = await tornarAdminEFazerLogin(
      admin.usuarioId,
      "admin2@example.com",
      "senhaDeTeste123",
    );

    await request(app)
      .delete(`/api/v1/admin/usuarios/${alvo.usuarioId}`)
      .set(headersAdmin)
      .expect(204);

    // A fazenda dela some junto (nao fica orfa) -- o token ainda "parece"
    // valido, mas a fazenda por tras dele nao existe mais.
    const resposta = await request(app)
      .get(`/api/v1/fazendas/${alvo.fazendaId}/bovinos`)
      .set(alvo.headers);
    expect(resposta.status).toBe(404);
  });

  it("admin não consegue apagar a própria conta por essa rota (422)", async () => {
    const admin = await registrarUsuario({ email: "admin3@example.com", senha: "senhaDeTeste123" });
    const headersAdmin = await tornarAdminEFazerLogin(
      admin.usuarioId,
      "admin3@example.com",
      "senhaDeTeste123",
    );

    await request(app)
      .delete(`/api/v1/admin/usuarios/${admin.usuarioId}`)
      .set(headersAdmin)
      .expect(422);
  });

  it("usuário comum (não-admin) não consegue apagar conta de outro (403)", async () => {
    const naoAdmin = await registrarUsuario();
    const alvo = await registrarUsuario();

    await request(app)
      .delete(`/api/v1/admin/usuarios/${alvo.usuarioId}`)
      .set(naoAdmin.headers)
      .expect(403);
  });
});
