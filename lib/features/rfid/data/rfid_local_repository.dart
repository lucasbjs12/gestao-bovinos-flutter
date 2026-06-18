import 'package:sqflite/sqflite.dart';

import 'leitura_rfid.dart';

class RfidLocalRepository {
  final Database _db;

  RfidLocalRepository(this._db);

  Future<List<LeituraRfid>> listarLeituras() async {
    final rows = await _db.rawQuery('''
      SELECT r.bovinoId, r.antena, r.timestamp,
             b.numeroBrinco, b.nomeAnimal
      FROM leitura_rfid r
      LEFT JOIN bovinos b ON b.id = r.bovinoId
      ORDER BY r.timestamp DESC
      LIMIT 200
    ''');
    return rows.map(LeituraRfid.fromMap).toList();
  }
}
