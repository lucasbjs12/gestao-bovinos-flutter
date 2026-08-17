import 'plano.dart';

enum StatusPlano { gratuito, pendente, ativo, vencido, cancelado }

/// Resposta de `GET /fazendas/:id/assinatura` -- a assinatura efetiva da
/// fazenda (a do dono, mesmo pra quem entrou como convidado) mais a
/// contagem atual de animais, pronta pra montar a barra de progresso.
class AssinaturaAtual {
  final StatusPlano status;
  final int? limiteAnimaisAtual; // null = ilimitado
  final int contagemAnimais;
  final Plano? plano;
  final DateTime? proximaCobranca;
  final DateTime? canceladaEm;

  const AssinaturaAtual({
    required this.status,
    required this.limiteAnimaisAtual,
    required this.contagemAnimais,
    this.plano,
    this.proximaCobranca,
    this.canceladaEm,
  });

  bool get limiteAtingido =>
      limiteAnimaisAtual != null && contagemAnimais >= limiteAnimaisAtual!;

  /// Quantos cadastros ainda cabem antes do limite (null = sem limite).
  int? get vagasRestantes =>
      limiteAnimaisAtual == null ? null : (limiteAnimaisAtual! - contagemAnimais).clamp(0, 1 << 30);

  double? get progresso =>
      limiteAnimaisAtual == null || limiteAnimaisAtual == 0
          ? null
          : (contagemAnimais / limiteAnimaisAtual!).clamp(0, 1).toDouble();

  factory AssinaturaAtual.fromMap(Map<String, dynamic> m) {
    final statusStr = m['status'] as String? ?? 'gratuito';
    return AssinaturaAtual(
      status: StatusPlano.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => StatusPlano.gratuito,
      ),
      limiteAnimaisAtual: m['limiteAnimaisAtual'] as int?,
      contagemAnimais: m['contagemAnimais'] as int? ?? 0,
      plano: m['plano'] != null ? Plano.fromMap(m['plano'] as Map<String, dynamic>) : null,
      proximaCobranca: m['proximaCobranca'] != null
          ? DateTime.tryParse(m['proximaCobranca'] as String)
          : null,
      canceladaEm:
          m['canceladaEm'] != null ? DateTime.tryParse(m['canceladaEm'] as String) : null,
    );
  }
}
