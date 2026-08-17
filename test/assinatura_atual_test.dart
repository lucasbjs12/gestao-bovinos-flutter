import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_bovinos_app/features/planos/data/assinatura_atual.dart';

Map<String, dynamic> _mapa({
  String status = 'gratuito',
  int? limiteAnimaisAtual = 15,
  int contagemAnimais = 0,
}) {
  return {
    'status': status,
    'limiteAnimaisAtual': limiteAnimaisAtual,
    'contagemAnimais': contagemAnimais,
  };
}

void main() {
  group('AssinaturaAtual.fromMap', () {
    test('decodifica status e limite corretamente', () {
      final a = AssinaturaAtual.fromMap(_mapa(status: 'ativo', limiteAnimaisAtual: 150));
      expect(a.status, StatusPlano.ativo);
      expect(a.limiteAnimaisAtual, 150);
    });

    test('status desconhecido cai em gratuito (não trava a tela)', () {
      final a = AssinaturaAtual.fromMap(_mapa(status: 'algo-novo-do-backend'));
      expect(a.status, StatusPlano.gratuito);
    });

    test('limiteAnimaisAtual null vira "sem limite" (plano ilimitado)', () {
      final a = AssinaturaAtual.fromMap(_mapa(limiteAnimaisAtual: null));
      expect(a.limiteAnimaisAtual, isNull);
      expect(a.limiteAtingido, isFalse);
      expect(a.vagasRestantes, isNull);
      expect(a.progresso, isNull);
    });
  });

  group('AssinaturaAtual.limiteAtingido / vagasRestantes / progresso', () {
    test('abaixo do limite: não atingido, progresso proporcional', () {
      final a = AssinaturaAtual.fromMap(_mapa(limiteAnimaisAtual: 15, contagemAnimais: 12));
      expect(a.limiteAtingido, isFalse);
      expect(a.vagasRestantes, 3);
      expect(a.progresso, closeTo(0.8, 0.001));
    });

    test('exatamente no limite: atingido, zero vagas', () {
      final a = AssinaturaAtual.fromMap(_mapa(limiteAnimaisAtual: 15, contagemAnimais: 15));
      expect(a.limiteAtingido, isTrue);
      expect(a.vagasRestantes, 0);
      expect(a.progresso, 1.0);
    });

    test('acima do limite (não deveria acontecer, mas não quebra): continua atingido', () {
      final a = AssinaturaAtual.fromMap(_mapa(limiteAnimaisAtual: 15, contagemAnimais: 20));
      expect(a.limiteAtingido, isTrue);
      expect(a.vagasRestantes, 0);
      expect(a.progresso, 1.0);
    });
  });
}
