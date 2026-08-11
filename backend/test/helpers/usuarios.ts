import request from "supertest";
import { app } from "./app";

interface UsuarioRegistrado {
  accessToken: string;
  refreshToken: string;
  usuarioId: string;
  fazendaId: string;
  headers: { Authorization: string };
}

let contador = 0;

export async function registrarUsuario(
  overrides: Partial<{ nome: string; email: string; senha: string; nomeFazenda: string }> = {},
): Promise<UsuarioRegistrado> {
  contador += 1;
  const resposta = await request(app)
    .post("/api/v1/auth/registro")
    .send({
      nome: overrides.nome ?? `Usuario Teste ${contador}`,
      email: overrides.email ?? `usuario.teste.${contador}@example.com`,
      senha: overrides.senha ?? "senhaDeTeste123",
      nomeFazenda: overrides.nomeFazenda,
    })
    .expect(201);

  const { accessToken, refreshToken, usuario, fazenda } = resposta.body.data;
  return {
    accessToken,
    refreshToken,
    usuarioId: usuario.id,
    fazendaId: fazenda.id,
    headers: { Authorization: `Bearer ${accessToken}` },
  };
}
