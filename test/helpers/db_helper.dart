import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> criarDbTeste() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final db = await databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 2,
      singleInstance: false,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE invernadas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            descricao TEXT,
            urlFoto TEXT,
            observacoes TEXT,
            syncId TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE bovinos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nomeAnimal TEXT,
            codigoEpc TEXT,
            codigoInterno TEXT,
            numeroBrinco TEXT,
            raca TEXT,
            dataNascimento TEXT,
            dataNascimentoMillis INTEGER,
            pesoAtualKg REAL,
            pelagem TEXT,
            sexo TEXT,
            categoria TEXT,
            status TEXT,
            origem TEXT,
            observacoes TEXT,
            foto TEXT,
            invernadaId INTEGER REFERENCES invernadas(id) ON DELETE SET NULL,
            idMae INTEGER REFERENCES bovinos(id) ON DELETE SET NULL,
            estaDeCria INTEGER NOT NULL DEFAULT 0,
            syncId TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE eventos_sanitarios (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            syncId TEXT,
            tipo TEXT,
            dataEvento TEXT,
            dataEventoMillis INTEGER,
            invernadaId INTEGER,
            produtoUtilizado TEXT,
            dosagem TEXT,
            responsavel TEXT,
            observacoes TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE evento_sanitario_bovino (
            eventoId INTEGER NOT NULL,
            bovinoId INTEGER NOT NULL,
            PRIMARY KEY (eventoId, bovinoId),
            FOREIGN KEY (eventoId) REFERENCES eventos_sanitarios(id) ON DELETE CASCADE,
            FOREIGN KEY (bovinoId) REFERENCES bovinos(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE baixas_bovinos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bovinoId INTEGER NOT NULL,
            motivo TEXT,
            observacoes TEXT,
            dataBaixa TEXT,
            dataBaixaMillis INTEGER,
            FOREIGN KEY (bovinoId) REFERENCES bovinos(id) ON DELETE CASCADE
          )
        ''');
      },
    ),
  );
  return db;
}
