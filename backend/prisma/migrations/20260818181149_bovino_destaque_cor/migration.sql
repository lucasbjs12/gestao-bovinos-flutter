-- CreateEnum
CREATE TYPE "CorDestaque" AS ENUM ('amarelo', 'azul', 'verde', 'vermelho', 'roxo', 'laranja');

-- AlterTable
ALTER TABLE "bovinos" ADD COLUMN     "cor_destaque" "CorDestaque",
ADD COLUMN     "rotulo_destaque" TEXT;
