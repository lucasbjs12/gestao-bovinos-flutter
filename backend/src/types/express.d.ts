import { Papel } from "@prisma/client";

declare global {
  namespace Express {
    interface Request {
      usuario?: {
        id: string;
        isAdmin: boolean;
        nome: string;
      };
      fazendaAtiva?: {
        id: string;
        donoId: string;
        papel: Papel;
      };
    }
  }
}

export {};
