-- CreateEnum
CREATE TYPE "StatusPlano" AS ENUM ('gratuito', 'pendente', 'ativo', 'vencido', 'cancelado');

-- CreateEnum
CREATE TYPE "PeriodicidadePlano" AS ENUM ('mensal', 'anual');

-- CreateTable
CREATE TABLE "planos" (
    "id" UUID NOT NULL,
    "slug" TEXT NOT NULL,
    "nome" TEXT NOT NULL,
    "descricao" TEXT,
    "periodicidade" "PeriodicidadePlano" NOT NULL,
    "valor_centavos" INTEGER NOT NULL,
    "limite_animais" INTEGER,
    "recursos" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "ativo" BOOLEAN NOT NULL DEFAULT true,
    "destaque" BOOLEAN NOT NULL DEFAULT false,
    "ordem" INTEGER NOT NULL DEFAULT 0,
    "criado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "planos_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "assinaturas" (
    "id" UUID NOT NULL,
    "usuario_id" UUID NOT NULL,
    "plano_id" UUID,
    "status" "StatusPlano" NOT NULL DEFAULT 'gratuito',
    "limite_animais_atual" INTEGER NOT NULL DEFAULT 15,
    "iniciada_em" TIMESTAMP(3),
    "proxima_cobranca" TIMESTAMP(3),
    "cancelada_em" TIMESTAMP(3),
    "mercadopago_preapproval_id" TEXT,
    "mercadopago_payment_id" TEXT,
    "criado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "atualizado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "assinaturas_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "planos_slug_periodicidade_key" ON "planos"("slug", "periodicidade");

-- CreateIndex
CREATE UNIQUE INDEX "assinaturas_usuario_id_key" ON "assinaturas"("usuario_id");

-- AddForeignKey
ALTER TABLE "assinaturas" ADD CONSTRAINT "assinaturas_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "usuarios"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "assinaturas" ADD CONSTRAINT "assinaturas_plano_id_fkey" FOREIGN KEY ("plano_id") REFERENCES "planos"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Seed dos planos comerciais (configuráveis daqui em diante -- editar/adicionar
-- linha nesta tabela é o jeito de mudar preço/limite, sem tocar em código).
-- Desconto anual = pague 10 meses, use 12 (valor_anual = valor_mensal * 10).
INSERT INTO "planos" ("id", "slug", "nome", "descricao", "periodicidade", "valor_centavos", "limite_animais", "recursos", "ativo", "destaque", "ordem") VALUES
  (gen_random_uuid(), 'gratuito',    'Grátis',       'Para conhecer o sistema de verdade, sem prazo de teste.', 'mensal', 0,      15,   ARRAY[]::TEXT[], true, false, 0),
  (gen_random_uuid(), 'essencial',   'Essencial',    'Para quem está começando a organizar o rebanho.',         'mensal', 2390,   50,   ARRAY[]::TEXT[], true, false, 1),
  (gen_random_uuid(), 'essencial',   'Essencial',    'Para quem está começando a organizar o rebanho.',         'anual',  23900,  50,   ARRAY[]::TEXT[], true, false, 1),
  (gen_random_uuid(), 'produtor',    'Produtor',     'O mais usado -- espaço de sobra pra crescer.',            'mensal', 4499,   150,  ARRAY[]::TEXT[], true, true,  2),
  (gen_random_uuid(), 'produtor',    'Produtor',     'O mais usado -- espaço de sobra pra crescer.',            'anual',  44990,  150,  ARRAY[]::TEXT[], true, true,  2),
  (gen_random_uuid(), 'fazenda',     'Fazenda',      'Para operações de médio porte.',                          'mensal', 12399,  500,  ARRAY[]::TEXT[], true, false, 3),
  (gen_random_uuid(), 'fazenda',     'Fazenda',      'Para operações de médio porte.',                          'anual',  123990, 500,  ARRAY[]::TEXT[], true, false, 3),
  (gen_random_uuid(), 'fazenda-pro', 'Fazenda Pro',  'Rebanho sem limite de tamanho.',                          'mensal', 16999,  NULL, ARRAY[]::TEXT[], true, false, 4),
  (gen_random_uuid(), 'fazenda-pro', 'Fazenda Pro',  'Rebanho sem limite de tamanho.',                          'anual',  169990, NULL, ARRAY[]::TEXT[], true, false, 4);

-- Assinatura "gratuito" pra todo usuário que já existia antes desta migration
-- (quem se cadastrar dali em diante ganha a linha no momento do registro).
INSERT INTO "assinaturas" ("id", "usuario_id", "status", "limite_animais_atual")
SELECT gen_random_uuid(), "id", 'gratuito', 15 FROM "usuarios";
