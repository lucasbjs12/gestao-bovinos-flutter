-- AlterTable
ALTER TABLE "usuarios" ADD COLUMN     "email_verificado" BOOLEAN NOT NULL DEFAULT false;

-- CreateTable
CREATE TABLE "verificacao_email_tokens" (
    "id" UUID NOT NULL,
    "usuario_id" UUID NOT NULL,
    "token_hash" TEXT NOT NULL,
    "expira_em" TIMESTAMP(3) NOT NULL,
    "usado_em" TIMESTAMP(3),

    CONSTRAINT "verificacao_email_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "verificacao_email_tokens_usuario_id_idx" ON "verificacao_email_tokens"("usuario_id");

-- AddForeignKey
ALTER TABLE "verificacao_email_tokens" ADD CONSTRAINT "verificacao_email_tokens_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "usuarios"("id") ON DELETE CASCADE ON UPDATE CASCADE;
