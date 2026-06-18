import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_bovinos_app/features/bovinos/data/bovino.dart';

void main() {
  group('Bovino.fromMap / toMap', () {
    test('roundtrip preserva todos os campos', () {
      final original = Bovino(
        id: 1,
        syncId: 'sync-abc',
        numeroBrinco: 'B001',
        nomeAnimal: 'Mimosa',
        raca: 'Nelore',
        categoria: 'Vaca',
        sexo: 'Fêmea',
        status: 'Ativo',
        pesoAtualKg: 450.5,
        dataNascimento: '01/01/2020',
        dataNascimentoMillis: 1577836800000,
        estaDeCria: 1,
        invernadaId: 2,
      );

      final map = original.toMap();
      final restored = Bovino.fromMap({...map, 'invernadaDescricao': null});

      expect(restored.id, original.id);
      expect(restored.syncId, original.syncId);
      expect(restored.numeroBrinco, original.numeroBrinco);
      expect(restored.nomeAnimal, original.nomeAnimal);
      expect(restored.raca, original.raca);
      expect(restored.categoria, original.categoria);
      expect(restored.sexo, original.sexo);
      expect(restored.status, original.status);
      expect(restored.pesoAtualKg, original.pesoAtualKg);
      expect(restored.dataNascimento, original.dataNascimento);
      expect(restored.dataNascimentoMillis, original.dataNascimentoMillis);
      expect(restored.estaDeCria, original.estaDeCria);
      expect(restored.invernadaId, original.invernadaId);
    });

    test('status padrão é Ativo quando ausente no map', () {
      final b = Bovino.fromMap({'numeroBrinco': 'X', 'syncId': 's'});
      expect(b.status, 'Ativo');
    });

    test('estaDeCria padrão é 0 quando ausente no map', () {
      final b = Bovino.fromMap({'numeroBrinco': 'X', 'syncId': 's'});
      expect(b.estaDeCria, 0);
    });

    test('toMap não inclui id quando é null', () {
      final b = Bovino.criar(numeroBrinco: 'B002');
      expect(b.toMap().containsKey('id'), isFalse);
    });

    test('copyWith substitui apenas os campos passados', () {
      final b = Bovino.criar(numeroBrinco: 'B003');
      final copia = b.copyWith(id: 99);
      expect(copia.id, 99);
      expect(copia.numeroBrinco, 'B003');
      expect(copia.syncId, b.syncId);
    });
  });
}
