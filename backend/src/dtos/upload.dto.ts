import { z } from "zod";

export const assinarUploadQuerySchema = z.object({
  pasta: z.enum(["bovinos", "invernadas"]).optional(),
});
export type AssinarUploadQuery = z.infer<typeof assinarUploadQuerySchema>;
