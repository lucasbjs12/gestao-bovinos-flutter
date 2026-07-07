import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_bovinos_app/core/sync/sync_refs.dart';
import 'package:gestao_bovinos_app/features/bovinos/data/bovino.dart';
import 'package:gestao_bovinos_app/features/bovinos/data/bovino_local_repository.dart';
import 'package:gestao_bovinos_app/features/invernadas/data/invernada.dart';
import 'package:gestao_bovinos_app/features/invernadas/data/invernada_local_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show Database;

import 'helpers/db_helper.dart';

/// Cobre a tradução id local ↔ syncId usada pelo sync. O cenário-chave é o
/// "aparelho novo": os ids locais do aparelho de origem não valem aqui, e as
/// referências precisam chegar corretas mesmo assim.
void main() {
  group('SyncRefs', () {
    late Database db;
    late BovinoLocalRepository bovinos;
    late InvernadaLocalRepository invernadas;

    setUp(() async {
      db = await criarDbTeste();
      bovinos = BovinoLocalRepository(db);
      invernadas = InvernadaLocalRepository(db);
    });

    test('syncIdPorId e idPorSyncId fazem o caminho de ida e volta', () async {
      final id = await invernadas.inserirOuSubstituirPorSyncId(
        const Invernada(syncId: 'inv-abc', descricao: 'Norte'),
      );

      expect(await SyncRefs.syncIdPorId(db, 'invernadas', id), 'inv-abc');
      expect(await SyncRefs.idPorSyncId(db, 'invernadas', 'inv-abc'), id);
      expect(await SyncRefs.syncIdPorId(db, 'invernadas', 999), isNull);
      expect(await SyncRefs.idPorSyncId(db, 'invernadas', 'nao-existe'), isNull);
    });

    test('idRemotoResolvido prioriza o syncId sobre o id legado', () async {
      // Simula aparelho novo: a invernada "Sul" tem id local diferente do
      // que tinha no aparelho de origem (legacyId aponta para "Norte").
      final idNorte = await invernadas.inserirOuSubstituirPorSyncId(
        const Invernada(syncId: 'inv-norte', descricao: 'Norte'),
      );
      final idSul = await invernadas.inserirOuSubstituirPorSyncId(
        const Invernada(syncId: 'inv-sul', descricao: 'Sul'),
      );

      final resolvido = await SyncRefs.idRemotoResolvido(
        db,
        'invernadas',
        syncId: 'inv-sul',
        legacyId: idNorte, // id "errado" vindo do aparelho de origem
      );
      expect(resolvido, idSul);
    });

    test('idRemotoResolvido com syncId desconhecido devolve null '
        '(nunca cai no id legado de outro aparelho)', () async {
      final idNorte = await invernadas.inserirOuSubstituirPorSyncId(
        const Invernada(syncId: 'inv-norte', descricao: 'Norte'),
      );

      final resolvido = await SyncRefs.idRemotoResolvido(
        db,
        'invernadas',
        syncId: 'inv-que-ainda-nao-chegou',
        legacyId: idNorte,
      );
      expect(resolvido, isNull);
    });

    test('idRemotoResolvido sem syncId mantém o comportamento legado', () async {
      final resolvido = await SyncRefs.idRemotoResolvido(
        db,
        'invernadas',
        syncId: null,
        legacyId: 7,
      );
      expect(resolvido, 7);
    });

    test('idsDeBovinosRemotos resolve por syncIds ignorando os legados', () async {
      final b1 = await bovinos.inserirOuSubstituirPorSyncId(
        Bovino(syncId: 'bov-1', numeroBrinco: 'B01', status: 'Ativo'),
      );
      final b2 = await bovinos.inserirOuSubstituirPorSyncId(
        Bovino(syncId: 'bov-2', numeroBrinco: 'B02', status: 'Ativo'),
      );

      final ids = await SyncRefs.idsDeBovinosRemotos(
        db,
        syncIds: ['bov-2', 'bov-1', 'bov-fantasma'],
        legacyIds: [998, 999], // lixo do aparelho de origem, deve ser ignorado
      );
      expect(ids.toSet(), {b1, b2});
    });

    test('idsDeBovinosRemotos sem syncIds filtra legados inexistentes', () async {
      final b1 = await bovinos.inserirOuSubstituirPorSyncId(
        Bovino(syncId: 'bov-3', numeroBrinco: 'B03', status: 'Ativo'),
      );

      final ids = await SyncRefs.idsDeBovinosRemotos(
        db,
        syncIds: const [],
        legacyIds: [b1, 999],
      );
      expect(ids, [b1]);
    });

    test('syncIdsDeBovinos traduz ids locais para subir à nuvem', () async {
      final b1 = await bovinos.inserirOuSubstituirPorSyncId(
        Bovino(syncId: 'bov-4', numeroBrinco: 'B04', status: 'Ativo'),
      );

      final syncIds = await SyncRefs.syncIdsDeBovinos(db, [b1, 999]);
      expect(syncIds, ['bov-4']);
    });
  });
}
