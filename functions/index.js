const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const crypto = require("crypto");

const cloudinaryApiKey = defineSecret("CLOUDINARY_API_KEY");
const cloudinaryApiSecret = defineSecret("CLOUDINARY_API_SECRET");

// Gera a assinatura de upload do Cloudinary para o usuário logado.
// O API secret nunca sai do servidor — o app recebe apenas a assinatura,
// válida para um upload na pasta do próprio usuário.
exports.assinarUploadCloudinary = onCall(
  {
    region: "southamerica-east1",
    secrets: [cloudinaryApiKey, cloudinaryApiSecret],
  },
  (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Faça login para enviar fotos.");
    }

    const timestamp = Math.floor(Date.now() / 1000);
    const folder = `bovinos/${request.auth.uid}`;

    // Cloudinary espera os parâmetros em ordem alfabética, serializados
    // como query string, com o API secret concatenado no final (SHA-1).
    const paramsParaAssinar = `folder=${folder}&timestamp=${timestamp}`;
    const signature = crypto
      .createHash("sha1")
      .update(paramsParaAssinar + cloudinaryApiSecret.value())
      .digest("hex");

    return {
      apiKey: cloudinaryApiKey.value(),
      timestamp: timestamp,
      folder: folder,
      signature: signature,
    };
  }
);
