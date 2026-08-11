-- CreateEnum
CREATE TYPE "StatusAssinatura" AS ENUM ('pendente', 'ativo', 'bloqueado', 'vencido');

-- CreateEnum
CREATE TYPE "Papel" AS ENUM ('dono', 'convidado');

-- CreateEnum
CREATE TYPE "CategoriaBovino" AS ENUM ('Vaca', 'Novilha', 'Terneira', 'Terneiro', 'Novilho', 'Touro', 'Boi');

-- CreateEnum
CREATE TYPE "MotivoBaixa" AS ENUM ('Morte', 'Venda', 'Furto', 'Outros');

-- CreateEnum
CREATE TYPE "TipoEventoSanitario" AS ENUM ('Vacinacao', 'Vermifugacao', 'Medicacao', 'Castracao', 'Banho', 'Outros');

-- CreateTable
CREATE TABLE "usuarios" (
    "id" UUID NOT NULL,
    "nome" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "senha_hash" TEXT NOT NULL,
    "is_admin" BOOLEAN NOT NULL DEFAULT false,
    "status_assinatura" "StatusAssinatura" NOT NULL DEFAULT 'pendente',
    "plano" TEXT,
    "vencimento" TIMESTAMP(3),
    "criado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "usuarios_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "refresh_tokens" (
    "id" UUID NOT NULL,
    "usuario_id" UUID NOT NULL,
    "token_hash" TEXT NOT NULL,
    "expira_em" TIMESTAMP(3) NOT NULL,
    "revogado_em" TIMESTAMP(3),

    CONSTRAINT "refresh_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "fazendas" (
    "id" UUID NOT NULL,
    "dono_id" UUID NOT NULL,
    "nome" TEXT NOT NULL,
    "criado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "fazendas_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "membros" (
    "fazenda_id" UUID NOT NULL,
    "usuario_id" UUID NOT NULL,
    "papel" "Papel" NOT NULL,
    "nome" TEXT,
    "desde" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "membros_pkey" PRIMARY KEY ("fazenda_id","usuario_id")
);

-- CreateTable
CREATE TABLE "convites" (
    "codigo" TEXT NOT NULL,
    "fazenda_id" UUID NOT NULL,
    "papel" "Papel" NOT NULL DEFAULT 'convidado',
    "criado_por" UUID,
    "criado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expira_em" TIMESTAMP(3) NOT NULL,
    "usado" BOOLEAN NOT NULL DEFAULT false,
    "usado_por" UUID,

    CONSTRAINT "convites_pkey" PRIMARY KEY ("codigo")
);

-- CreateTable
CREATE TABLE "invernadas" (
    "id" UUID NOT NULL,
    "fazenda_id" UUID NOT NULL,
    "descricao" TEXT NOT NULL,
    "hectares" DECIMAL(10,2),
    "url_foto" TEXT,
    "observacoes" TEXT,
    "atualizado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "invernadas_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "bovinos" (
    "id" UUID NOT NULL,
    "fazenda_id" UUID NOT NULL,
    "nome_animal" TEXT,
    "codigo_epc" TEXT,
    "codigo_interno" TEXT,
    "numero_brinco" TEXT NOT NULL,
    "raca" TEXT,
    "data_nascimento" DATE,
    "peso_atual_kg" DECIMAL(8,2),
    "pelagem" TEXT,
    "categoria" "CategoriaBovino" NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'Ativo',
    "origem" TEXT,
    "observacoes" TEXT,
    "foto" TEXT,
    "invernada_id" UUID,
    "id_mae" UUID,
    "esta_de_cria" BOOLEAN NOT NULL DEFAULT false,
    "atualizado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "bovinos_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "baixas_bovinos" (
    "id" UUID NOT NULL,
    "bovino_id" UUID NOT NULL,
    "motivo" "MotivoBaixa" NOT NULL,
    "observacoes" TEXT,
    "data_baixa" DATE NOT NULL,

    CONSTRAINT "baixas_bovinos_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "movimentacoes_invernada" (
    "id" UUID NOT NULL,
    "fazenda_id" UUID NOT NULL,
    "bovino_id" UUID NOT NULL,
    "data" DATE NOT NULL,
    "invernada_anterior_id" UUID,
    "nova_invernada_id" UUID,
    "responsavel" TEXT,
    "observacoes" TEXT,

    CONSTRAINT "movimentacoes_invernada_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "eventos_sanitarios" (
    "id" UUID NOT NULL,
    "fazenda_id" UUID NOT NULL,
    "tipo" "TipoEventoSanitario" NOT NULL,
    "data_evento" DATE,
    "invernada_id" UUID,
    "produto_utilizado" TEXT,
    "dosagem" TEXT,
    "responsavel" TEXT,
    "observacoes" TEXT,

    CONSTRAINT "eventos_sanitarios_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "evento_sanitario_bovino" (
    "evento_id" UUID NOT NULL,
    "bovino_id" UUID NOT NULL,

    CONSTRAINT "evento_sanitario_bovino_pkey" PRIMARY KEY ("evento_id","bovino_id")
);

-- CreateTable
CREATE TABLE "atividades" (
    "id" UUID NOT NULL,
    "fazenda_id" UUID NOT NULL,
    "autor_id" UUID NOT NULL,
    "autor_nome" TEXT,
    "acao" TEXT NOT NULL,
    "descricao" TEXT NOT NULL,
    "criado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "atividades_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "usuarios_email_key" ON "usuarios"("email");

-- CreateIndex
CREATE INDEX "refresh_tokens_usuario_id_idx" ON "refresh_tokens"("usuario_id");

-- CreateIndex
CREATE INDEX "invernadas_fazenda_id_idx" ON "invernadas"("fazenda_id");

-- CreateIndex
CREATE INDEX "bovinos_fazenda_id_numero_brinco_idx" ON "bovinos"("fazenda_id", "numero_brinco");

-- CreateIndex
CREATE INDEX "bovinos_invernada_id_idx" ON "bovinos"("invernada_id");

-- CreateIndex
CREATE INDEX "bovinos_id_mae_idx" ON "bovinos"("id_mae");

-- CreateIndex
CREATE INDEX "baixas_bovinos_bovino_id_idx" ON "baixas_bovinos"("bovino_id");

-- CreateIndex
CREATE INDEX "movimentacoes_invernada_fazenda_id_idx" ON "movimentacoes_invernada"("fazenda_id");

-- CreateIndex
CREATE INDEX "movimentacoes_invernada_bovino_id_idx" ON "movimentacoes_invernada"("bovino_id");

-- CreateIndex
CREATE INDEX "eventos_sanitarios_fazenda_id_idx" ON "eventos_sanitarios"("fazenda_id");

-- CreateIndex
CREATE INDEX "atividades_fazenda_id_criado_em_idx" ON "atividades"("fazenda_id", "criado_em" DESC);

-- AddForeignKey
ALTER TABLE "refresh_tokens" ADD CONSTRAINT "refresh_tokens_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "usuarios"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "fazendas" ADD CONSTRAINT "fazendas_dono_id_fkey" FOREIGN KEY ("dono_id") REFERENCES "usuarios"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "membros" ADD CONSTRAINT "membros_fazenda_id_fkey" FOREIGN KEY ("fazenda_id") REFERENCES "fazendas"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "membros" ADD CONSTRAINT "membros_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "usuarios"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "convites" ADD CONSTRAINT "convites_fazenda_id_fkey" FOREIGN KEY ("fazenda_id") REFERENCES "fazendas"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "convites" ADD CONSTRAINT "convites_criado_por_fkey" FOREIGN KEY ("criado_por") REFERENCES "usuarios"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "convites" ADD CONSTRAINT "convites_usado_por_fkey" FOREIGN KEY ("usado_por") REFERENCES "usuarios"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "invernadas" ADD CONSTRAINT "invernadas_fazenda_id_fkey" FOREIGN KEY ("fazenda_id") REFERENCES "fazendas"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bovinos" ADD CONSTRAINT "bovinos_fazenda_id_fkey" FOREIGN KEY ("fazenda_id") REFERENCES "fazendas"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bovinos" ADD CONSTRAINT "bovinos_invernada_id_fkey" FOREIGN KEY ("invernada_id") REFERENCES "invernadas"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bovinos" ADD CONSTRAINT "bovinos_id_mae_fkey" FOREIGN KEY ("id_mae") REFERENCES "bovinos"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "baixas_bovinos" ADD CONSTRAINT "baixas_bovinos_bovino_id_fkey" FOREIGN KEY ("bovino_id") REFERENCES "bovinos"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "movimentacoes_invernada" ADD CONSTRAINT "movimentacoes_invernada_fazenda_id_fkey" FOREIGN KEY ("fazenda_id") REFERENCES "fazendas"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "movimentacoes_invernada" ADD CONSTRAINT "movimentacoes_invernada_bovino_id_fkey" FOREIGN KEY ("bovino_id") REFERENCES "bovinos"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "movimentacoes_invernada" ADD CONSTRAINT "movimentacoes_invernada_invernada_anterior_id_fkey" FOREIGN KEY ("invernada_anterior_id") REFERENCES "invernadas"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "movimentacoes_invernada" ADD CONSTRAINT "movimentacoes_invernada_nova_invernada_id_fkey" FOREIGN KEY ("nova_invernada_id") REFERENCES "invernadas"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "eventos_sanitarios" ADD CONSTRAINT "eventos_sanitarios_fazenda_id_fkey" FOREIGN KEY ("fazenda_id") REFERENCES "fazendas"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "eventos_sanitarios" ADD CONSTRAINT "eventos_sanitarios_invernada_id_fkey" FOREIGN KEY ("invernada_id") REFERENCES "invernadas"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "evento_sanitario_bovino" ADD CONSTRAINT "evento_sanitario_bovino_evento_id_fkey" FOREIGN KEY ("evento_id") REFERENCES "eventos_sanitarios"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "evento_sanitario_bovino" ADD CONSTRAINT "evento_sanitario_bovino_bovino_id_fkey" FOREIGN KEY ("bovino_id") REFERENCES "bovinos"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "atividades" ADD CONSTRAINT "atividades_fazenda_id_fkey" FOREIGN KEY ("fazenda_id") REFERENCES "fazendas"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "atividades" ADD CONSTRAINT "atividades_autor_id_fkey" FOREIGN KEY ("autor_id") REFERENCES "usuarios"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
