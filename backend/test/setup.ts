import dotenv from "dotenv";

dotenv.config();

if (!process.env.DATABASE_URL_TEST) {
  throw new Error(
    "DATABASE_URL_TEST nao definida no .env -- crie um banco separado para os testes " +
      "(ver README) antes de rodar `npm test`.",
  );
}

// Precisa acontecer antes de qualquer import de ../src/config/prisma nos
// arquivos de teste, senao o Prisma conecta no banco de desenvolvimento.
process.env.DATABASE_URL = process.env.DATABASE_URL_TEST;
