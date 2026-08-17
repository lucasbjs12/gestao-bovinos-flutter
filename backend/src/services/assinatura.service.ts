import { StatusPlano } from "@prisma/client";
import { env } from "../config/env";
import { AppError } from "../exceptions/AppError";
import { assinaturaRepository } from "../repositories/assinatura.repository";
import { bovinoRepository } from "../repositories/bovino.repository";
import { planoRepository } from "../repositories/plano.repository";
import { usuarioRepository } from "../repositories/usuario.repository";
import { mercadoPagoClient } from "./mercadoPago.client";

type AssinaturaComPlano = NonNullable<Awaited<ReturnType<typeof assinaturaRepository.buscarPorUsuarioId>>>;

/// "Vencido" (renovação falhou) e "cancelado" (usuário pediu) só voltam pro
/// Gratuito quando o período já pago/tentado passa -- não na hora. Isso é
/// checado aqui (lazy, sem cron) toda vez que a assinatura é lida, igual ao
/// jeito que Usuario.vencimento já era comparado com "agora" antes desta
/// feature existir.
function jaExpirou(a: AssinaturaComPlano): boolean {
  return (
    (a.status === StatusPlano.vencido || a.status === StatusPlano.cancelado) &&
    a.proximaCobranca !== null &&
    a.proximaCobranca < new Date()
  );
}

function calcularProximaCobranca(de: Date, periodicidade?: "mensal" | "anual"): Date {
  const proxima = new Date(de);
  proxima.setMonth(proxima.getMonth() + (periodicidade === "anual" ? 12 : 1));
  return proxima;
}

export const assinaturaService = {
  /// Toda conta tem uma assinatura a partir do registro (ver auth.service.ts).
  /// Isso aqui só cobre contas criadas antes dessa feature existir -- cria a
  /// linha "gratuito" na primeira vez que alguém pedir, em vez de rodar um
  /// backfill em massa. Também é aqui que "vencido"/"cancelado" expirados
  /// voltam pro Gratuito sozinhos.
  async obterOuCriar(usuarioId: string) {
    const existente = await assinaturaRepository.buscarPorUsuarioId(usuarioId);
    if (!existente) return assinaturaRepository.criarGratuita(usuarioId);

    if (jaExpirou(existente)) {
      return assinaturaRepository.atualizar(usuarioId, {
        status: StatusPlano.gratuito,
        planoId: null,
        limiteAnimaisAtual: 15,
        proximaCobranca: null,
        canceladaEm: null,
      });
    }
    return existente;
  },

  /// Assinatura efetiva de uma fazenda (a do DONO, não de quem está
  /// logado -- mesmo padrão de verificarLimiteParaNovoCadastro) + quantos
  /// animais já ocupam o limite agora, pra montar a barra de progresso.
  async obterParaFazenda(fazendaId: string, donoId: string) {
    const [assinatura, contagemAnimais] = await Promise.all([
      this.obterOuCriar(donoId),
      bovinoRepository.contarAtivos(fazendaId),
    ]);
    return { assinatura, contagemAnimais };
  },

  /// Chamado antes de criar um bovino: conta o rebanho ativo da fazenda e
  /// compara com o limite da assinatura do DONO da fazenda (não de quem
  /// está logado -- convidado opera sob o limite de quem o convidou, mesmo
  /// padrão do exigirAssinaturaAtiva). limiteAnimaisAtual null = ilimitado.
  async verificarLimiteParaNovoCadastro(fazendaId: string, donoId: string) {
    const assinatura = await this.obterOuCriar(donoId);
    if (assinatura.limiteAnimaisAtual === null) return;

    const atual = await bovinoRepository.contarAtivos(fazendaId);
    if (atual >= assinatura.limiteAnimaisAtual) {
      throw new AppError(
        403,
        "limite_do_plano_atingido",
        `Seu plano permite gerenciar até ${assinatura.limiteAnimaisAtual} animais. Faça upgrade para continuar cadastrando.`,
        { limite: assinatura.limiteAnimaisAtual, atual },
      );
    }
  },

  /// Passo 1 do upgrade: cria a assinatura recorrente no Mercado Pago
  /// ("pagamento pendente" -- sem cartão nenhum passando pelo nosso
  /// backend) e devolve o link de checkout. Não libera nada ainda -- só o
  /// webhook confirmando "authorized" ativa o plano de verdade.
  async iniciarCheckout(usuarioId: string, planoId: string) {
    const usuario = await usuarioRepository.buscarPorId(usuarioId);
    if (!usuario) throw AppError.naoEncontrado("Usuario");
    await this.obterOuCriar(usuario.id);

    const plano = await planoRepository.buscarPorId(planoId);
    if (!plano || !plano.ativo) {
      throw AppError.naoEncontrado("Plano");
    }
    if (plano.valorCentavos <= 0) {
      throw AppError.validacao("O plano Gratuito não passa por checkout");
    }

    const preapproval = await mercadoPagoClient.criarPreapproval({
      reason: `Gestão de Rebanho — ${plano.nome} (${plano.periodicidade})`,
      externalReference: usuario.id,
      payerEmail: usuario.email,
      valorReais: plano.valorCentavos / 100,
      frequencia:
        plano.periodicidade === "anual"
          ? { frequency: 12, frequencyType: "months" }
          : { frequency: 1, frequencyType: "months" },
      backUrl: `${env.frontendUrl}/planos/retorno`,
    });

    await assinaturaRepository.atualizar(usuario.id, {
      planoId: plano.id,
      status: StatusPlano.pendente,
      mercadoPagoPreapprovalId: preapproval.id,
    });

    return { checkoutUrl: preapproval.init_point };
  },

  /// Único lugar que pode virar "ativo" -- chamado só pelo controller do
  /// webhook, nunca por uma rota que o app chama diretamente.
  async processarWebhookPreapproval(preapprovalId: string) {
    // Nunca confia no corpo da notificação -- ele só avisa "algo mudou";
    // isso aqui busca o estado de verdade direto na API do Mercado Pago.
    const preapproval = await mercadoPagoClient.buscarPreapproval(preapprovalId);

    const assinatura = await assinaturaRepository.buscarPorPreapprovalId(preapprovalId);
    if (!assinatura) return; // notificação de uma preapproval que não é nossa

    if (preapproval.status === "authorized") {
      const plano = assinatura.planoId ? await planoRepository.buscarPorId(assinatura.planoId) : null;
      const agora = new Date();
      await assinaturaRepository.atualizar(assinatura.usuarioId, {
        status: StatusPlano.ativo,
        limiteAnimaisAtual: plano?.limiteAnimais ?? null,
        iniciadaEm: assinatura.iniciadaEm ?? agora,
        proximaCobranca: calcularProximaCobranca(agora, plano?.periodicidade),
        canceladaEm: null,
      });
    } else if (preapproval.status === "paused") {
      // Falha na renovação (cartão recusado etc) -- Mercado Pago tenta de
      // novo sozinho por um tempo antes de cancelar de vez.
      await assinaturaRepository.atualizar(assinatura.usuarioId, { status: StatusPlano.vencido });
    } else if (preapproval.status === "cancelled") {
      await assinaturaRepository.atualizar(assinatura.usuarioId, {
        status: StatusPlano.cancelado,
        canceladaEm: assinatura.canceladaEm ?? new Date(),
      });
    }
    // "pending": nada a fazer, é o estado inicial (aguardando o produtor
    // terminar de cadastrar o meio de pagamento no Mercado Pago).
  },

  /// Cancelamento pedido pelo produtor (não confundir com o webhook acima,
  /// que reflete cancelamento feito no próprio Mercado Pago). Mantém o
  /// limite do plano pago até proximaCobranca -- a volta pro Gratuito
  /// acontece sozinha em obterOuCriar quando esse prazo passar.
  async cancelar(usuarioId: string) {
    const assinatura = await this.obterOuCriar(usuarioId);
    if (!assinatura.mercadoPagoPreapprovalId || assinatura.status !== StatusPlano.ativo) {
      throw AppError.validacao("Não há assinatura paga ativa para cancelar");
    }
    await mercadoPagoClient.cancelarPreapproval(assinatura.mercadoPagoPreapprovalId);
    return assinaturaRepository.atualizar(usuarioId, {
      status: StatusPlano.cancelado,
      canceladaEm: new Date(),
    });
  },

  /// Ativação manual por um admin (ex: pagamento combinado fora do Mercado
  /// Pago, cortesia, suporte). Não mexe em mercadoPagoPreapprovalId -- essa
  /// assinatura simplesmente não tem uma preapproval associada, então o
  /// webhook nunca vai tocar nela.
  async ativarPlanoManual(usuarioId: string, planoId: string, proximaCobranca: Date) {
    const plano = await planoRepository.buscarPorId(planoId);
    if (!plano || !plano.ativo) {
      throw AppError.naoEncontrado("Plano");
    }

    const atual = await this.obterOuCriar(usuarioId);
    return assinaturaRepository.atualizar(usuarioId, {
      planoId: plano.id,
      status: StatusPlano.ativo,
      limiteAnimaisAtual: plano.limiteAnimais,
      iniciadaEm: atual.iniciadaEm ?? new Date(),
      proximaCobranca,
      canceladaEm: null,
    });
  },
};
