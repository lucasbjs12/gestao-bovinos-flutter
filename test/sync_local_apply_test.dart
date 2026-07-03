import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_bovinos_app/features/bovinos/data/bovino.dart';
import 'package:gestao_bovinos_app/features/bovinos/data/bovino_local_repository.dart';
import 'package:gestao_bovinos_app/features/eventos_sanitarios/data/evento_sanitario.dart';
import 'package:gestao_bovinos_app/features/eventos_sanitarios/data/evento_sanitario_local_repository.dart';
import 'package:gestao_bovinos_app/features/invernadas/data/invernada.dart';
import 'package:gestao_bovinos_app/features/invernadas/data/invernada_local_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show Database;

import 'helpers/db_helper.dart';

/// Simula o que RealtimeSyncService e InitialSyncService fazem com o banco
/// local quando mudanças remotas chegam (upsert/delete por syncId) — o cenário
/// crítico de dias offline seguidos de uma rajada de mudanças ao voltar o sinal.
void main() {
  group('Aplicação local do sync', () {
    late Database db;
    late BovinoLocalRepository bovinos;
    late InvernadaLocalRepository invernadas;
    late EventoSanitarioLocalRepository eventos;

    setUp(() async {
      db = await criarDbTeste();
      bovinos = BovinoLocalRepository(db);
      invernadas = InvernadaLocalRepository(db);
      eventos = EventoSanitarioLocalRepository(db);
    });

    Bovino bovinoRemoto(
      String syncId, {
      String brinco = 'B001',
      String? nome,
      int? invernadaId,
    }) =>
        Bovino(
          syncId: syncId,
          numeroBrinco: brinco,
          nomeAnimal: nome,
          invernadaId: invernadaId,
          status: 'Ativo',
        );

    Future<int> contar(String tabela) async {
      final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $tabela');
      return rows.first['c'] as int;
    }

    Future<List<int>> bovinosVinculados(String eventoSyncId) async {
      final rows = await db.rawQuery('''
        SELECT eb.bovinoId FROM evento_sanitario_bovino eb
        JOIN eventos_sanitarios e ON e.id = eb.eventoId
        WHERE e.syncId = ? ORDER BY eb.bovinoId
      ''', [eventoSyncId]);
      return rows.map((r) => r['bovinoId'] as int).toList();
    }

    test('upsert remoto atualiza campos preservando o id local', () async {
      final id1 = await bovinos.inserirOuSubstituirPorSyncId(
        bovinoRemoto('sync-a', nome: 'Mimosa'),
      );
      final id2 = await bovinos.inserirOuSubstituirPorSyncId(
        bovinoRemoto('sync-a', nome: 'Mimosa Editada'),
      );

      expect(id2, id1);
      expect(await contar('bovinos'), 1);
      final b = await bovinos.buscarPorId(id1);
      expect(b!.nomeAnimal, 'Mimosa Editada');
    });

    test('vínculos de evento sobrevivem ao update remoto do bovino', () async {
      final bId = await bovinos.inserirOuSubstituirPorSyncId(bovinoRemoto('sync-b'));
      await eventos.inserirComBovinos(
        EventoSanitario.criar(tipo: 'Vacinação'),
        [bId],
      );

      await bovinos.inserirOuSubstituirPorSyncId(
        bovinoRemoto('sync-b', nome: 'Atualizado no outro aparelho'),
      );

      final doEvento = await eventos.listarPorBovino(bId);
      expect(doEvento.length, 1);
      expect(doEvento.first.tipo, 'Vacinação');
    });

    test('update que chega antes do create cria o registro (fora de ordem)', () async {
      await bovinos.inserirOuSubstituirPorSyncId(
        bovinoRemoto('sync-fora-de-ordem', brinco: 'FO01'),
      );
      expect(await contar('bovinos'), 1);
    });

    test('delete remoto remove o bovino; delete de inexistente não lança', () async {
      await bovinos.inserirOuSubstituirPorSyncId(bovinoRemoto('sync-del'));
      await bovinos.excluirPorSyncId('sync-del');
      expect(await contar('bovinos'), 0);

      await bovinos.excluirPorSyncId('sync-nunca-existiu');
      expect(await contar('bovinos'), 0);
    });

    test('delete remoto do bovino deixa vínculo órfão no join (FKs desligadas) '
        'mas as consultas não retornam o fantasma', () async {
      final bId = await bovinos.inserirOuSubstituirPorSyncId(bovinoRemoto('sync-orfao'));
      final eventoId = await eventos.inserirComBovinos(
        EventoSanitario.criar(tipo: 'Vermifugação'),
        [bId],
      );

      await bovinos.excluirPorSyncId('sync-orfao');

      // O PRAGMA foreign_keys fica desligado no app, então o ON DELETE CASCADE
      // não dispara — o vínculo órfão permanece na tabela...
      expect(await contar('evento_sanitario_bovino'), 1);
      // ...mas o JOIN com bovinos filtra o fantasma nas consultas reais.
      final doEvento = await eventos.listarBovinosDoEvento(eventoId);
      expect(doEvento, isEmpty);
    });

    test('update remoto de evento substitui a lista de bovinos vinculados', () async {
      final b1 = await bovinos.inserirOuSubstituirPorSyncId(bovinoRemoto('sync-1', brinco: 'V01'));
      final b2 = await bovinos.inserirOuSubstituirPorSyncId(bovinoRemoto('sync-2', brinco: 'V02'));
      final b3 = await bovinos.inserirOuSubstituirPorSyncId(bovinoRemoto('sync-3', brinco: 'V03'));

      const eventoSyncId = 'sync-evento-1';
      final evento = EventoSanitario(syncId: eventoSyncId, tipo: 'Vacinação');

      await eventos.inserirOuSubstituirPorSyncId(evento, [b1, b2]);
      expect(await bovinosVinculados(eventoSyncId), [b1, b2]);

      await eventos.inserirOuSubstituirPorSyncId(evento, [b2, b3]);
      expect(await bovinosVinculados(eventoSyncId), [b2, b3]);
      expect(await contar('eventos_sanitarios'), 1);
    });

    test('upsert de invernada preserva id e a referência dos bovinos', () async {
      final invId = await invernadas.inserirOuSubstituirPorSyncId(
        const Invernada(syncId: 'sync-inv', descricao: 'Potreiro Norte'),
      );
      final bId = await bovinos.inserirOuSubstituirPorSyncId(
        bovinoRemoto('sync-c', invernadaId: invId),
      );

      final invId2 = await invernadas.inserirOuSubstituirPorSyncId(
        const Invernada(syncId: 'sync-inv', descricao: 'Potreiro Norte Renomeado'),
      );

      expect(invId2, invId);
      final b = await bovinos.buscarPorId(bId);
      expect(b!.invernadaId, invId);
      final inv = await invernadas.buscarPorSyncId('sync-inv');
      expect(inv!.descricao, 'Potreiro Norte Renomeado');
    });

    test('reaplicar o lote completo não duplica registros (retry da sync inicial)',
        () async {
      // Mesma ordem do InitialSyncService: invernadas → bovinos → idMae → eventos.
      Future<void> aplicarLote() async {
        final invId = await invernadas.inserirOuSubstituirPorSyncId(
          const Invernada(syncId: 'lote-inv', descricao: 'Invernada Sul'),
        );
        final maeId = await bovinos.inserirOuSubstituirPorSyncId(
          bovinoRemoto('lote-mae', brinco: 'M01', invernadaId: invId),
        );
        await bovinos.inserirOuSubstituirPorSyncId(
          bovinoRemoto('lote-cria', brinco: 'C01', invernadaId: invId),
        );
        await bovinos.atualizarIdMaePorSyncId('lote-cria', maeId);

        final b1 = (await bovinos.buscarPorSyncId('lote-mae'))!.id!;
        await eventos.inserirOuSubstituirPorSyncId(
          const EventoSanitario(syncId: 'lote-ev', tipo: 'Everminação'),
          [b1],
        );
      }

      await aplicarLote();
      await aplicarLote(); // retry após falha parcial / reinstalação

      expect(await contar('invernadas'), 1);
      expect(await contar('bovinos'), 2);
      expect(await contar('eventos_sanitarios'), 1);
      expect(await contar('evento_sanitario_bovino'), 1);

      final cria = await bovinos.buscarPorSyncId('lote-cria');
      final mae = await bovinos.buscarPorSyncId('lote-mae');
      expect(cria!.idMae, mae!.id);
    });
  });
}
