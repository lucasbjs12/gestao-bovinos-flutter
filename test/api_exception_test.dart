import 'package:flutter_test/flutter_test.dart';

import 'package:gestao_bovinos_app/core/api/api_exception.dart';

void main() {
  // Regressao: um 403 de "limite do plano atingido" era tratado igual a
  // "sem internet" pelo BovinoRemoteRepository.salvar() -- caia na fila de
  // retry (Outbox) e o cadastro que o backend recusou continuava parecendo
  // "salvo com sucesso" na tela, ficando la ate o proximo ciclo de sync
  // descobrir a divergencia. A correcao depende desta classificacao estar
  // certa: erros de regra de negocio (4xx, exceto 401/429) sao definitivos
  // e nunca devem entrar na fila; so falha de rede de verdade deve.
  group('ApiException.ehPermanente', () {
    test('403 (limite do plano, brinco duplicado, etc) e permanente', () {
      expect(
        const ApiException(
          statusCode: 403,
          message: 'Limite atingido',
          codigo: 'limite_do_plano_atingido',
        ).ehPermanente,
        isTrue,
      );
    });

    test('422 (validacao) e permanente', () {
      expect(
        const ApiException(statusCode: 422, message: 'Dados invalidos').ehPermanente,
        isTrue,
      );
    });

    test('409 (conflito) e permanente', () {
      expect(
        const ApiException(statusCode: 409, message: 'Ja existe').ehPermanente,
        isTrue,
      );
    });

    test('401 (token expirado) NAO e permanente -- passageiro', () {
      expect(
        const ApiException(statusCode: 401, message: 'Nao autorizado').ehPermanente,
        isFalse,
      );
    });

    test('429 (rate limit) NAO e permanente -- passageiro', () {
      expect(
        const ApiException(statusCode: 429, message: 'Muitas requisicoes').ehPermanente,
        isFalse,
      );
    });

    test('500 (erro do servidor) NAO e permanente -- passageiro', () {
      expect(
        const ApiException(statusCode: 500, message: 'Erro interno').ehPermanente,
        isFalse,
      );
    });
  });
}
