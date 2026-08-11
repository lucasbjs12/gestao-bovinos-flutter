import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show Database;

import 'package:gestao_bovinos_app/core/api/api_client.dart';
import 'package:gestao_bovinos_app/core/sync/sync_status_service.dart';
import 'package:gestao_bovinos_app/sync/polling_sync_service.dart';

import 'helpers/db_helper.dart';
import 'helpers/token_storage_falso.dart';

http.Response _pagina(List<Map<String, dynamic>> itens) => http.Response(
  jsonEncode({
    'success': true,
    'message': 'OK',
    'data': {
      'itens': itens,
      'paginacao': {'page': 1, 'pageSize': 100, 'total': itens.length, 'totalPaginas': 1},
    },
  }),
  200,
  headers: {'content-type': 'application/json'},
);

/// Bug real relatado pelo usuário: "fiz o manejo dos bovinos... ele perdeu
/// o manejo, agora todos aparecem como nunca feito o manejo". Causa: o
/// PollingSyncService reconstruía o EventoSanitario local sem preencher
/// `dataEventoMillis` (campo só local, o backend só guarda a data em si),
/// então toda rodada de sync zerava esse campo -- e é exatamente ele que a
/// tela "Sem manejo" usa (`MAX(e.dataEventoMillis)`) pra saber a data do
/// último manejo de cada bovino.
void main() {
  test(
    'depois do sync, dataEventoMillis do evento continua preenchido (não fica null)',
    () async {
      final Database db = await criarDbTeste();
      final falso = TokenStorageFalso();

      final cliente = MockClient((request) async {
        if (request.url.path.endsWith('/eventos-sanitarios')) {
          return _pagina([
            {
              'id': 'evt-1',
              'tipo': 'Vacinacao',
              'dataEvento': '2026-07-15T00:00:00.000Z',
              'invernadaId': null,
              'produtoUtilizado': null,
              'dosagem': null,
              'responsavel': null,
              'observacoes': null,
              'bovinos': [],
            },
          ]);
        }
        return _pagina([]);
      });
      final api = ApiClient(httpClient: cliente, tokenStorage: falso);

      final pollingSync = PollingSyncService(apiClient: api);
      await pollingSync.start(uid: 'f1', db: db, sync: SyncStatusService());

      final rows = await db.query(
        'eventos_sanitarios',
        where: 'syncId = ?',
        whereArgs: ['evt-1'],
      );
      expect(rows, hasLength(1));
      expect(
        rows.first['dataEventoMillis'],
        isNotNull,
        reason: 'sem isso a tela "Sem manejo" acha que o bovino nunca teve manejo feito',
      );
      expect(
        DateTime.fromMillisecondsSinceEpoch(rows.first['dataEventoMillis'] as int).year,
        2026,
      );
    },
  );
}
