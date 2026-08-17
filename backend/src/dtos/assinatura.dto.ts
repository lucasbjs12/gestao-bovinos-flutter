import { z } from "zod";

export const iniciarCheckoutSchema = z.object({
  planoId: z.string().uuid("planoId invalido"),
});

export type IniciarCheckoutInput = z.infer<typeof iniciarCheckoutSchema>;
