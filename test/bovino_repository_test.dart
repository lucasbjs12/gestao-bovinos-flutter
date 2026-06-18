import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_bovinos_app/features/bovinos/data/bovino.dart';
import 'package:gestao_bovinos_app/features/bovinos/data/bovino_local_repository.dart';

import 'helpers/db_helper.dart';

void main() {
  group('BovinoLocalRepository', () {
    late BovinoLocalRepository repo;

    setUp(() async {
      final db = await criarDbTeste();
      repo = BovinoLocalRepository(db);
    });

    Future<int> inserir(String brinco, {String? categoria, String status = 'Ativo'}) {
      final b = Bovino(
        syncId: 'sync-$brinco',
        numeroBrinco: brinco,
        categoria: categoria,
        status: status,
      );
      return repo.inserir(b);
    }

    test('inserir e buscarPorId retornam o mesmo bovino', () async {
      final id = await inserir('B001', categoria: 'Vaca');
      final b = await repo.buscarPorId(id);
      expect(b, isNotNull);
      expect(b!.numeroBrinco, 'B001');
      expect(b.categoria, 'Vaca');
    });

    test('listarAtivos não retorna bovinos inativos', () async {
      await inserir('B002', status: 'Ativo');
      await inserir('B003', status: 'Inativo');

      final ativos = await repo.listarAtivos();
      expect(ativos.any((b) => b.numeroBrinco == 'B002'), isTrue);
      expect(ativos.any((b) => b.numeroBrinco == 'B003'), isFalse);
    });

    test('listarAtivos filtra por termo (brinco)', () async {
      await inserir('ALPHA001');
      await inserir('BETA002');

      final resultado = await repo.listarAtivos(termo: 'ALPHA');
      expect(resultado.length, 1);
      expect(resultado.first.numeroBrinco, 'ALPHA001');
    });

    test('listarAtivos filtra por categoria', () async {
      await inserir('C001', categoria: 'Vaca');
      await inserir('C002', categoria: 'Touro');

      final vacas = await repo.listarAtivos(categoria: 'Vaca');
      expect(vacas.every((b) => b.categoria == 'Vaca'), isTrue);
    });

    test('listarAtivos respeita limit e offset (paginação)', () async {
      for (var i = 1; i <= 5; i++) {
        await inserir('PAG00$i');
      }

      final pagina1 = await repo.listarAtivos(limit: 2, offset: 0);
      final pagina2 = await repo.listarAtivos(limit: 2, offset: 2);

      expect(pagina1.length, 2);
      expect(pagina2.length, 2);
      expect(pagina1.first.numeroBrinco, isNot(equals(pagina2.first.numeroBrinco)));
    });

    test('brincoEmUso retorna true para brinco duplicado', () async {
      await inserir('DUP001');
      expect(await repo.brincoEmUso('DUP001'), isTrue);
    });

    test('brincoEmUso retorna false ao excluir o próprio id', () async {
      final id = await inserir('DUP002');
      expect(await repo.brincoEmUso('DUP002', excluirId: id), isFalse);
    });

    test('excluir remove o bovino', () async {
      final id = await inserir('DEL001');
      await repo.excluir(id);
      expect(await repo.buscarPorId(id), isNull);
    });

    test('atualizar persiste mudanças', () async {
      final id = await inserir('UPD001', categoria: 'Terneiro');
      final original = (await repo.buscarPorId(id))!;
      final atualizado = Bovino(
        id: original.id,
        syncId: original.syncId,
        numeroBrinco: 'UPD001',
        categoria: 'Touro',
        status: 'Ativo',
      );
      await repo.atualizar(atualizado);
      final resultado = await repo.buscarPorId(id);
      expect(resultado!.categoria, 'Touro');
    });
  });
}
