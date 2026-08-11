import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_bovinos_app/core/utils/data_iso.dart';

/// Bug real em produção: o backend usa `z.coerce.date()` (Zod/Node), que
/// não entende "dd/MM/yyyy" -- `new Date("15/07/2026")` vira `Invalid
/// Date` do lado do servidor e o Zod rejeita com 422. Como as escritas são
/// fire-and-forget, isso falhava silenciosamente: o evento/bovino/baixa
/// nunca chegava no servidor e, na sincronização seguinte, sumia do
/// aparelho por "não existir no servidor".
void main() {
  group('dataBrParaIso', () {
    test('converte dd/MM/yyyy para yyyy-MM-dd', () {
      expect(dataBrParaIso('15/07/2026'), '2026-07-15');
    });

    test('preenche com zero à esquerda quando faltar', () {
      expect(dataBrParaIso('5/7/2026'), '2026-07-05');
    });

    test('null continua null', () {
      expect(dataBrParaIso(null), isNull);
    });

    test('string vazia vira null', () {
      expect(dataBrParaIso(''), isNull);
    });

    test('formato inesperado (sem 3 partes) passa direto, sem quebrar', () {
      expect(dataBrParaIso('2026-07-15'), '2026-07-15');
    });
  });
}
