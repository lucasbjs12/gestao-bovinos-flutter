import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    globals: true,
    setupFiles: ["./test/setup.ts"],
    testTimeout: 20_000,
    hookTimeout: 20_000,
    // Todos os arquivos de teste compartilham o mesmo banco Postgres de teste
    // (limpo entre arquivos), entao rodam em sequencia, nao em paralelo.
    fileParallelism: false,
  },
});
