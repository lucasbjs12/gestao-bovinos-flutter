import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../assinatura_provider.dart';
import '../data/assinatura_atual.dart';
import '../data/plano.dart';

class PlanosScreen extends StatefulWidget {
  const PlanosScreen({super.key});

  @override
  State<PlanosScreen> createState() => _PlanosScreenState();
}

class _PlanosScreenState extends State<PlanosScreen> {
  PeriodicidadePlano _periodicidade = PeriodicidadePlano.mensal;
  bool _abrindoCheckout = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AssinaturaProvider>().carregarPlanos();
    });
  }

  Future<void> _assinar(Plano plano) async {
    setState(() => _abrindoCheckout = true);
    try {
      final url = await context.read<AssinaturaProvider>().iniciarCheckout(plano.id);
      if (!mounted) return;
      final abriu = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (!abriu) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o checkout.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao iniciar assinatura: $e')));
    } finally {
      if (mounted) setState(() => _abrindoCheckout = false);
    }
  }

  Future<void> _confirmarCancelamento() async {
    final assinatura = context.read<AssinaturaProvider>().assinatura;
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar assinatura?'),
        content: Text(
          assinatura?.proximaCobranca != null
              ? 'Seu plano continua valendo até ${_formatarData(assinatura!.proximaCobranca!)}. '
                  'Depois disso, você volta pro plano Gratuito.'
              : 'Seu plano pago será cancelado.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar assinatura'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;
    try {
      await context.read<AssinaturaProvider>().cancelar();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Assinatura cancelada.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao cancelar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AssinaturaProvider>();
    final assinatura = provider.assinatura;
    final colorScheme = Theme.of(context).colorScheme;

    final planosDaPeriodicidade = provider.planos
        .where((p) => p.gratuito || p.periodicidade == _periodicidade)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Planos e Assinatura')),
      body: assinatura == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => provider.atualizar(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _CardPlanoAtual(
                    assinatura: assinatura,
                    onCancelar: _confirmarCancelamento,
                  ),
                  const SizedBox(height: 24),
                  Text('Planos disponíveis', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Center(
                    child: SegmentedButton<PeriodicidadePlano>(
                      segments: const [
                        ButtonSegment(
                          value: PeriodicidadePlano.mensal,
                          label: Text('Mensal'),
                        ),
                        ButtonSegment(
                          value: PeriodicidadePlano.anual,
                          label: Text('Anual · economize'),
                        ),
                      ],
                      selected: {_periodicidade},
                      onSelectionChanged: (s) => setState(() => _periodicidade = s.first),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (provider.planos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    ...planosDaPeriodicidade.map(
                      (plano) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CardPlano(
                          plano: plano,
                          // planoId já é gravado no checkout, antes do
                          // pagamento confirmar -- com status "pendente"
                          // ainda não houve troca de verdade, então não
                          // marca o plano-alvo como se já fosse o atual.
                          ehAtual: assinatura.status != StatusPlano.pendente &&
                              (assinatura.plano?.id == plano.id ||
                                  (plano.gratuito && assinatura.plano == null)),
                          carregando: _abrindoCheckout,
                          onAssinar: () => _assinar(plano),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Os preços mudam apenas se você escolher um plano diferente -- '
                    'seu limite de animais nunca some, mesmo se um pagamento atrasar.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
    );
  }
}

String _formatarData(DateTime d) => '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';

class _CardPlanoAtual extends StatelessWidget {
  const _CardPlanoAtual({required this.assinatura, required this.onCancelar});

  final AssinaturaAtual assinatura;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // planoId já é gravado no checkout, antes do pagamento confirmar -- com
    // status pendente ainda não houve troca de verdade (o limite abaixo
    // continua sendo o antigo), então não mostra o plano-alvo como atual.
    final nomePlano = assinatura.status == StatusPlano.pendente
        ? 'Gratuito'
        : assinatura.plano?.nome ?? 'Gratuito';
    final limite = assinatura.limiteAnimaisAtual;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Seu plano atual', style: Theme.of(context).textTheme.labelLarge),
                ),
                _ChipStatus(status: assinatura.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(nomePlano, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              limite == null
                  ? '${assinatura.contagemAnimais} animais cadastrados · sem limite'
                  : '${assinatura.contagemAnimais} de $limite animais cadastrados',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (limite != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: assinatura.progresso,
                  minHeight: 8,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  color: assinatura.limiteAtingido ? colorScheme.error : colorScheme.primary,
                ),
              ),
            ],
            if (assinatura.status == StatusPlano.pendente && assinatura.plano != null) ...[
              const SizedBox(height: 12),
              Text(
                'Assinatura do plano ${assinatura.plano!.nome} em processamento pelo Mercado '
                'Pago -- pode levar alguns minutos até ativar. O limite acima ainda é o do '
                'plano atual.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
            if (assinatura.status == StatusPlano.cancelado && assinatura.proximaCobranca != null) ...[
              const SizedBox(height: 12),
              Text(
                'Cancelada -- continua valendo até ${_formatarData(assinatura.proximaCobranca!)}.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
            if (assinatura.status == StatusPlano.ativo) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: onCancelar, child: const Text('Gerenciar assinatura')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChipStatus extends StatelessWidget {
  const _ChipStatus({required this.status});

  final StatusPlano status;

  @override
  Widget build(BuildContext context) {
    final (cor, texto) = switch (status) {
      StatusPlano.ativo => (Colors.green, 'Ativo'),
      StatusPlano.gratuito => (Colors.blueGrey, 'Gratuito'),
      StatusPlano.pendente => (Colors.orange, 'Pendente'),
      StatusPlano.vencido => (Colors.red, 'Vencido'),
      StatusPlano.cancelado => (Colors.red, 'Cancelado'),
    };
    return Chip(
      label: Text(texto, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      backgroundColor: cor.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: cor),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
    );
  }
}

class _CardPlano extends StatelessWidget {
  const _CardPlano({
    required this.plano,
    required this.ehAtual,
    required this.carregando,
    required this.onAssinar,
  });

  final Plano plano;
  final bool ehAtual;
  final bool carregando;
  final VoidCallback onAssinar;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final anual = plano.periodicidade == PeriodicidadePlano.anual;

    return Card(
      elevation: plano.destaque ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: plano.destaque ? colorScheme.primary : colorScheme.outlineVariant,
          width: plano.destaque ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(plano.nome, style: Theme.of(context).textTheme.titleMedium),
                if (plano.destaque) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.star, size: 16, color: colorScheme.primary),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              plano.limiteAnimais == null
                  ? 'Animais ilimitados'
                  : 'Até ${plano.limiteAnimais} animais',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (plano.gratuito)
              Text('R\$ 0', style: Theme.of(context).textTheme.headlineSmall)
            else ...[
              if (anual)
                Text(
                  'R\$ ${plano.valorReais.toStringAsFixed(2).replaceAll('.', ',')}/mês',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        decoration: TextDecoration.lineThrough,
                      ),
                ),
              Text(
                'R\$ ${plano.valorMensalEquivalente.toStringAsFixed(2).replaceAll('.', ',')}/mês',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (anual) ...[
                Text(
                  'R\$ ${plano.valorReais.toStringAsFixed(2).replaceAll('.', ',')} cobrados anualmente',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  // valor_anual = valor_mensal * 10 (paga 10, usa 12) -- a
                  // economia é sempre 2 meses, ou seja 1/5 do valor anual.
                  'Economize R\$ ${(plano.valorReais / 5).toStringAsFixed(2).replaceAll('.', ',')} por ano',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.green, fontWeight: FontWeight.w600),
                ),
              ],
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ehAtual
                  ? OutlinedButton(onPressed: null, child: const Text('Plano atual'))
                  : plano.gratuito
                      ? const SizedBox.shrink()
                      : FilledButton(
                          onPressed: carregando ? null : onAssinar,
                          child: const Text('Assinar'),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
