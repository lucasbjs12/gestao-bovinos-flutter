import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_bovinos_app/features/atividades/data/atividade.dart';
import 'package:gestao_bovinos_app/features/atividades/data/atividade_local_repository.dart';

import 'helpers/db_helper.dart';

void main() {
  group('AtividadeLocalRepository', () {
    late AtividadeLocalRepository repo;

    setUp(() async {
      final db = await criarDbTeste();
      repo = AtividadeLocalRepository(db);
    });

    Atividade atividade(String descricao, {int? millis, String? syncId}) =>
        Atividade(
          syncId: syncId ?? 'sync-$descricao',
          autorUid: 'uid-1',
          autorNome: 'Lucas',
          acao: 'bovino_salvo',
          descricao: descricao,
          dataMillis: millis ?? DateTime.now().millisecondsSinceEpoch,
        );

    test('inserir e listar retornam em ordem decrescente de data', () async {
      await repo.inserir(atividade('antiga', millis: 1000));
      await repo.inserir(atividade('recente', millis: 3000));
      await repo.inserir(atividade('meio', millis: 2000));

      final lista = await repo.listar();
      expect(lista.map((a) => a.descricao).toList(),
          ['recente', 'meio', 'antiga']);
    });

    test('listar respeita limit e offset (paginação)', () async {
      for (var i = 1; i <= 5; i++) {
        await repo.inserir(atividade('a$i', millis: i * 1000));
      }

      final pagina1 = await repo.listar(limit: 2, offset: 0);
      final pagina2 = await repo.listar(limit: 2, offset: 2);
      expect(pagina1.map((a) => a.descricao).toList(), ['a5', 'a4']);
      expect(pagina2.map((a) => a.descricao).toList(), ['a3', 'a2']);
    });

    test('upsert por syncId é idempotente (sync que desce não duplica)', () async {
      final a = atividade('vacinou o lote', syncId: 'sync-x', millis: 1000);
      await repo.inserirOuSubstituirPorSyncId(a);
      await repo.inserirOuSubstituirPorSyncId(a);

      final lista = await repo.listar();
      expect(lista.length, 1);
      expect(lista.first.descricao, 'vacinou o lote');
    });

    test('roundtrip preserva autor e ação', () async {
      await repo.inserir(atividade('deu baixa', millis: 500));
      final salvo = (await repo.listar()).first;
      expect(salvo.autorUid, 'uid-1');
      expect(salvo.autorNome, 'Lucas');
      expect(salvo.acao, 'bovino_salvo');
      expect(salvo.dataMillis, 500);
    });
  });
}
