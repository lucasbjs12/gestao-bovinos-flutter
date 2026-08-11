import { afterEach, describe, expect, it } from "vitest";
import request from "supertest";
import { app } from "./helpers/app";
import { limparBanco } from "./helpers/banco";
import { registrarUsuario } from "./helpers/usuarios";

afterEach(async () => {
  await limparBanco();
});

describe("Auth", () => {
  it("registra um usuario e cria a fazenda propria com ele como dono", async () => {
    const { usuarioId, fazendaId } = await registrarUsuario({ nomeFazenda: "Fazenda X" });
    expect(usuarioId).toBeTruthy();
    expect(fazendaId).toBeTruthy();
  });

  it("rejeita registro com e-mail duplicado", async () => {
    await registrarUsuario({ email: "duplicado@example.com" });
    const resposta = await request(app)
      .post("/api/v1/auth/registro")
      .send({ nome: "Outro", email: "duplicado@example.com", senha: "outraSenha123" });
    expect(resposta.status).toBe(409);
  });

  it("rejeita senha curta na validacao (422)", async () => {
    const resposta = await request(app)
      .post("/api/v1/auth/registro")
      .send({ nome: "Ze", email: "ze@example.com", senha: "123" });
    expect(resposta.status).toBe(422);
  });

  it("login com senha errada retorna 401", async () => {
    await registrarUsuario({ email: "login.teste@example.com", senha: "senhaCorreta123" });
    const resposta = await request(app)
      .post("/api/v1/auth/login")
      .send({ email: "login.teste@example.com", senha: "senhaErrada999" });
    expect(resposta.status).toBe(401);
  });

  it("GET /me sem token retorna 401", async () => {
    const resposta = await request(app).get("/api/v1/auth/me");
    expect(resposta.status).toBe(401);
  });

  it("GET /me com token valido retorna o usuario e a fazenda propria", async () => {
    const { headers } = await registrarUsuario();
    const resposta = await request(app).get("/api/v1/auth/me").set(headers);
    expect(resposta.status).toBe(200);
    expect(resposta.body.data.fazendaPropria).toBeTruthy();
  });

  it("refresh rotaciona o token e rejeita reuso do token antigo", async () => {
    const { refreshToken } = await registrarUsuario();

    const primeiro = await request(app)
      .post("/api/v1/auth/refresh")
      .send({ refreshToken })
      .expect(200);

    expect(primeiro.body.data.refreshToken).not.toBe(refreshToken);

    const reuso = await request(app).post("/api/v1/auth/refresh").send({ refreshToken });
    expect(reuso.status).toBe(401);
  });

  it("logout revoga o refresh token", async () => {
    const { refreshToken } = await registrarUsuario();
    await request(app).post("/api/v1/auth/logout").send({ refreshToken }).expect(200);
    const resposta = await request(app).post("/api/v1/auth/refresh").send({ refreshToken });
    expect(resposta.status).toBe(401);
  });
});
