import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:gestao_bovinos_app/core/api/api_client.dart';
import 'package:gestao_bovinos_app/core/sync/sync_status_service.dart';
import 'package:gestao_bovinos_app/features/bovinos/data/bovino_remote_repository.dart';

import 'helpers/token_storage_falso.dart';

/// Bug real relatado pelo usuário: escritas com data (evento sanitário,
/// nascimento, baixa, movimentação) nunca chegavam no servidor -- o Zod do
/// backend usa `z.coerce.date()`, que rejeita "dd/MM/yyyy" (o formato que
/// `_formatarData` produz em toda a UI) com 422 "Invalid date". Como a
/// escrita é fire-and-forget, isso falhava em silêncio; na sincronização
/// seguinte, o registro "sumia" do aparelho por não existir no servidor.
///
/// `BovinoRemoteRepository.salvar` e `EventoSanitarioRemoteRepository.salvar`
/// também foram corrigidos (mesma conversão), mas dependem de
/// `AppDatabase.instance` (armazenamento real de arquivo via
/// `path_provider`) pra resolver invernadaId/idMae/bovinoIds, o que exige
/// mockar um platform channel que este projeto não tem infra pra ainda --
/// a conversão em si já está coberta isoladamente em `data_iso_test.dart`.
/// `darBaixa` não depende de banco, então testa o caminho de rede real.
void main() {
  test('BovinoRemoteRepository.darBaixa manda dataBaixa em ISO, não dd/MM/yyyy', () async {
    final falso = TokenStorageFalso();

    Map<String, dynamic>? corpoRecebido;
    final cliente = MockClient((request) async {
      corpoRecebido = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({'success': true, 'message': 'OK', 'data': {}}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiClient(httpClient: cliente, tokenStorage: falso);
    final repo = BovinoRemoteRepository(uid: 'f1', sync: SyncStatusService(), apiClient: api);

    await repo.darBaixa('bov-3', motivo: 'Venda', dataBaixa: '28/02/2026');

    expect(corpoRecebido!['dataBaixa'], '2026-02-28');
    expect(corpoRecebido!['dataBaixa'], isNot('28/02/2026'));
  });
}
