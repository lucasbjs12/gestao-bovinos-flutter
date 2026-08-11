import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import 'sync_status_service.dart';

/// Fila local de escritas que não conseguiram chegar ao backend (offline ou
/// erro passageiro). Cada remote repository, ao falhar, enfileira aqui em
/// vez de simplesmente engolir o erro -- e o [PollingSyncService] tenta
/// esvaziar a fila a cada rodada (e quando a conexão volta).
///
/// Isso é o que substitui, pro backend REST, a fila offline automática que
/// o SDK do Firestore dava de graça.
class Outbox {
  final Database db;
  final ApiClient _api;

  Outbox(this.db, {ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  /// Operações de "salvar" (upsert): tenta PUT em [caminhoBase]/[syncId] e,
  /// se o registro ainda não existir no servidor (404), cai para POST em
  /// [caminhoBase] com o id incluído -- mesma lógica usada na escrita
  /// online, só que reaplicada aqui na hora do flush.
  Future<void> enfileirarUpsert({
    required String caminhoBase,
    required String syncId,
    required Map<String, dynamic> corpo,
    String? descricao,
  }) {
    return db.insert('pending_ops', {
      'tipo': 'upsert',
      'metodo': null,
      'caminho': caminhoBase,
      'syncId': syncId,
      'corpo': jsonEncode(corpo),
      'descricao': descricao,
      'criadoEm': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Uma chamada HTTP direta (DELETE, PATCH de baixa/reativação, POST de
  /// movimentação, etc) -- sem ambiguidade de criar-ou-atualizar.
  Future<void> enfileirarChamada({
    required String metodo,
    required String caminho,
    Object? corpo,
    String? descricao,
  }) {
    return db.insert('pending_ops', {
      'tipo': 'chamada',
      'metodo': metodo,
      'caminho': caminho,
      'syncId': null,
      'corpo': corpo == null ? null : jsonEncode(corpo),
      'descricao': descricao,
      'criadoEm': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Atalho pros remote repositories: atualiza o contador exibido na UI
  /// depois de enfileirar uma operação que falhou.
  Future<void> avisar(SyncStatusService sync) async {
    sync.atualizarPendencias(await contar());
  }

  Future<int> contar() async {
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM pending_ops');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  Future<List<String?>> listarDescricoes() async {
    final rows = await db.query('pending_ops', columns: ['descricao'], orderBy: 'id ASC');
    return rows.map((r) => r['descricao'] as String?).toList();
  }

  /// syncIds com um "salvar" pendente de envio -- o [PollingSyncService]
  /// usa isso pra NÃO apagar localmente um registro só porque ele ainda não
  /// chegou no servidor (senão um cadastro feito offline, ou bem na hora
  /// que a próxima rodada de sync bate, sumiria da tela sozinho).
  Future<Set<String>> syncIdsComEscritaPendente() async {
    final rows = await db.query(
      'pending_ops',
      columns: ['syncId'],
      where: "tipo = 'upsert'",
    );
    return rows.map((r) => r['syncId'] as String?).whereType<String>().toSet();
  }

  /// Tenta reenviar cada operação pendente, na ordem em que foram criadas.
  /// Erro passageiro (offline, 5xx, 401 mesmo depois do refresh) para a
  /// fila ali -- provavelmente ainda sem conexão, tenta de nova na próxima
  /// rodada, preservando a ordem. Erro permanente (4xx de validação: o
  /// payload é inválido e vai continuar sendo pra sempre, não importa
  /// quantas vezes reenviar) descarta só aquele item e segue os próximos --
  /// senão um único registro corrompido trava a fila inteira para sempre
  /// (aconteceu de verdade: um evento sanitário que ficou com a lista de
  /// animais vazia por causa de um bug já corrigido travou outras 14
  /// pendências atrás dele indefinidamente). Retorna quantas conseguiu
  /// esvaziar.
  Future<int> tentarEsvaziar() async {
    final api = _api;
    final pendentes = await db.query('pending_ops', orderBy: 'id ASC');
    var enviadas = 0;

    for (final op in pendentes) {
      final id = op['id'] as int;
      final corpoBruto = op['corpo'] as String?;
      final corpo = corpoBruto == null
          ? null
          : jsonDecode(corpoBruto) as Map<String, dynamic>;

      try {
        if (op['tipo'] == 'upsert') {
          final caminhoBase = op['caminho'] as String;
          final syncId = op['syncId'] as String;
          try {
            await api.put('$caminhoBase/$syncId', corpo: corpo);
          } on ApiException catch (e) {
            if (e.statusCode != 404) rethrow;
            await api.post(caminhoBase, corpo: {...?corpo, 'id': syncId});
          }
        } else {
          final caminho = op['caminho'] as String;
          switch (op['metodo']) {
            case 'POST':
              await api.post(caminho, corpo: corpo);
              break;
            case 'PUT':
              await api.put(caminho, corpo: corpo);
              break;
            case 'PATCH':
              await api.patch(caminho, corpo: corpo);
              break;
            case 'DELETE':
              await api.delete(caminho, corpo: corpo);
              break;
            default:
              // verbo desconhecido -- descarta em vez de travar a fila pra sempre
              break;
          }
        }
        await db.delete('pending_ops', where: 'id = ?', whereArgs: [id]);
        enviadas++;
      } on ApiException catch (e) {
        if (_ehErroPermanente(e)) {
          // Reenviar não vai adiantar nunca -- descarta e segue os
          // próximos, em vez de travar a fila pra sempre nesse item.
          await db.delete('pending_ops', where: 'id = ?', whereArgs: [id]);
          continue;
        }
        break; // 401/429/5xx -- provavelmente passageiro, tenta de novo depois
      } catch (_) {
        break; // sem conexão de verdade -- tenta de novo depois
      }
    }
    return enviadas;
  }

  bool _ehErroPermanente(ApiException e) {
    return e.statusCode >= 400 &&
        e.statusCode < 500 &&
        e.statusCode != 401 &&
        e.statusCode != 429;
  }
}
