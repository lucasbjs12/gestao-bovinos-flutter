import { env } from "../config/env";
import { AppError } from "../exceptions/AppError";
import { assinarParametrosCloudinary } from "../utils/assinaturaCloudinary";

export const uploadService = {
  assinarUpload(fazendaId: string, pasta?: string) {
    const { cloudName, apiKey, apiSecret } = env.cloudinary;
    if (!cloudName || !apiKey || !apiSecret) {
      throw new AppError(
        503,
        "upload_nao_configurado",
        "Upload de fotos nao configurado neste ambiente (variaveis CLOUDINARY_* ausentes)",
      );
    }

    const timestamp = Math.floor(Date.now() / 1000);
    const folder = `gestaobovinos/${fazendaId}${pasta ? `/${pasta}` : ""}`;

    const signature = assinarParametrosCloudinary({ folder, timestamp }, apiSecret);

    return {
      cloudName,
      apiKey,
      timestamp,
      folder,
      signature,
      uploadUrl: `https://api.cloudinary.com/v1_1/${cloudName}/image/upload`,
    };
  },
};
