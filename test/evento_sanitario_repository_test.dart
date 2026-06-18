import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_bovinos_app/features/bovinos/data/bovino.dart';
import 'package:gestao_bovinos_app/features/bovinos/data/bovino_local_repository.dart';
import 'package:gestao_bovinos_app/features/eventos_sanitarios/data/evento_sanitario.dart';
import 'package:gestao_bovinos_app/features/eventos_sanitarios/data/evento_sanitario_local_repository.dart';

import 'helpers/db_helper.dart';

void main() {
  group('EventoSanitarioLocalRepository', () {
    late EventoSanitarioLocalRepository repo;
    late BovinoLocalRepository bovinoRepo;
    late int bovinoId;

    setUp(() async {
      final db = await criarDbTeste();
      repo = EventoSanitarioLocalRepository(db);
      bovinoRepo = BovinoLocalRepository(db);
      bovinoId = await bovinoRepo.inserir(
        Bovino(syncId: 'sync-b1', numeroBrinco: 'B001', status: 'Ativo'),
      );
    });

    int counter = 0;

    Future<int> inserirEvento(
      String tipo, {
      String? produto,
      String? responsavel,
      int? millis,
    }) {
      counter++;
      return repo.inserirComBovinos(
        EventoSanitario(
          syncId: 'sync-$tipo-$counter',
          tipo: tipo,
          produtoUtilizado: produto,
          responsavel: responsavel,
          dataEventoMillis: millis ?? (counter * 1000),
        ),
        [bovinoId],
      );
    }

    test('inserirComBovinos e buscarCompletoPorId retornam o evento', () async {
      final id = await inserirEvento('Vacinação', produto: 'Aftosa');
      final evento = await repo.buscarCompletoPorId(id);
      expect(evento, isNotNull);
      expect(evento!.tipo, 'Vacinação');
      expect(evento.quantidadeBovinos, 1);
    });

    test('listar retorna todos os eventos em ordem decrescente', () async {
      await inserirEvento('Vacinação');
      await inserirEvento('Vermifugação');

      final lista = await repo.listar();
      expect(lista.length, 2);
      // Mais recente primeiro
      expect(lista.first.dataEventoMillis! >= lista.last.dataEventoMillis!, isTrue);
    });

    test('listar filtra por tipo', () async {
      await inserirEvento('Vacinação');
      await inserirEvento('Banho');

      final vacinacoes = await repo.listar(tipo: 'Vacinação');
      expect(vacinacoes.every((e) => e.tipo == 'Vacinação'), isTrue);
    });

    test('listar filtra por termo (produto)', () async {
      await inserirEvento('Vacinação', produto: 'Aftosa');
      await inserirEvento('Medicação', produto: 'Ivermectina');

      final resultado = await repo.listar(termo: 'aftosa');
      expect(resultado.length, 1);
      expect(resultado.first.produtoUtilizado, 'Aftosa');
    });

    test('listar respeita limit e offset (paginação)', () async {
      for (var i = 0; i < 5; i++) {
        await inserirEvento('Vacinação');
      }

      final pagina1 = await repo.listar(limit: 2, offset: 0);
      final pagina2 = await repo.listar(limit: 2, offset: 2);

      expect(pagina1.length, 2);
      expect(pagina2.length, 2);
      expect(pagina1.first.id, isNot(equals(pagina2.first.id)));
    });

    test('excluir remove o evento', () async {
      final id = await inserirEvento('Castração');
      await repo.excluir(id);
      expect(await repo.buscarCompletoPorId(id), isNull);
    });

    test('atualizarComBovinos persiste mudanças', () async {
      final id = await inserirEvento('Banho', responsavel: 'João');
      final original = (await repo.buscarCompletoPorId(id))!;
      await repo.atualizarComBovinos(
        EventoSanitario(
          id: original.id,
          syncId: original.syncId,
          tipo: 'Banho',
          responsavel: 'Maria',
          dataEventoMillis: original.dataEventoMillis,
        ),
        [bovinoId],
      );
      final atualizado = await repo.buscarCompletoPorId(id);
      expect(atualizado!.responsavel, 'Maria');
    });
  });
}
