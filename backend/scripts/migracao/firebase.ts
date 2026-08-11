import fs from "node:fs";
import path from "node:path";
import admin from "firebase-admin";

export function inicializarFirebaseAdmin(): admin.firestore.Firestore {
  const caminhoChave = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  if (!caminhoChave) {
    throw new Error(
      "FIREBASE_SERVICE_ACCOUNT_PATH nao definida no .env -- baixe a chave de service " +
        "account no Console do Firebase (Configuracoes do projeto > Contas de servico > " +
        "Gerar nova chave privada) e aponte o caminho do arquivo .json nessa variavel.",
    );
  }

  const caminhoAbsoluto = path.resolve(caminhoChave);
  if (!fs.existsSync(caminhoAbsoluto)) {
    throw new Error(`Arquivo de service account nao encontrado em: ${caminhoAbsoluto}`);
  }

  const credenciais = JSON.parse(fs.readFileSync(caminhoAbsoluto, "utf-8"));

  if (!admin.apps.length) {
    admin.initializeApp({ credential: admin.credential.cert(credenciais) });
  }

  return admin.firestore();
}
