import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Banco SQLite local, um arquivo por usuário (mesma estratégia de isolamento
/// por UID usada no Room do app Android: `gestao_bovinos_<uid>.db`).
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _database;
  String? _currentUid;

  Future<Database> instanceFor(String? uid) async {
    final resolvedUid = uid ?? 'anon';
    if (_database != null && _currentUid == resolvedUid) {
      return _database!;
    }

    await _database?.close();
    _currentUid = resolvedUid;
    _database = await _open(resolvedUid);
    return _database!;
  }

  Future<Database> _open(String uid) async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'gestao_bovinos_$uid.db');

    return openDatabase(
      dbPath,
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE eventos_sanitarios ADD COLUMN syncId TEXT',
          );
        }
      },
      onCreate: (db, version) async {
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
        await db.execute('CREATE INDEX idx_bovinos_invernadaId ON bovinos(invernadaId)');
        await db.execute('CREATE INDEX idx_bovinos_idMae ON bovinos(idMae)');
        await db.execute('CREATE INDEX idx_bovinos_numeroBrinco ON bovinos(numeroBrinco)');

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
        await db.execute('CREATE INDEX idx_eventos_invernadaId ON eventos_sanitarios(invernadaId)');

        await db.execute('''
          CREATE TABLE evento_sanitario_bovino (
            eventoId INTEGER NOT NULL,
            bovinoId INTEGER NOT NULL,
            PRIMARY KEY (eventoId, bovinoId),
            FOREIGN KEY (eventoId) REFERENCES eventos_sanitarios(id) ON DELETE CASCADE,
            FOREIGN KEY (bovinoId) REFERENCES bovinos(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_esb_eventoId ON evento_sanitario_bovino(eventoId)');
        await db.execute('CREATE INDEX idx_esb_bovinoId ON evento_sanitario_bovino(bovinoId)');

        await db.execute('''
          CREATE TABLE movimentacoes_invernada (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bovinoId INTEGER NOT NULL,
            data TEXT,
            dataMillis INTEGER,
            invernadaAnteriorId INTEGER,
            novaInvernadaId INTEGER,
            responsavel TEXT,
            observacoes TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_movimentacoes_bovinoId ON movimentacoes_invernada(bovinoId)');
        await db.execute('CREATE INDEX idx_movimentacoes_invernadaAnteriorId ON movimentacoes_invernada(invernadaAnteriorId)');
        await db.execute('CREATE INDEX idx_movimentacoes_novaInvernadaId ON movimentacoes_invernada(novaInvernadaId)');

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
        await db.execute('CREATE INDEX idx_baixas_bovinoId ON baixas_bovinos(bovinoId)');

        await db.execute('''
          CREATE TABLE leitura_rfid (
            bovinoId INTEGER NOT NULL,
            antena TEXT,
            timestamp TEXT NOT NULL,
            PRIMARY KEY (bovinoId, timestamp)
          )
        ''');
        await db.execute('CREATE INDEX idx_leitura_rfid_bovinoId ON leitura_rfid(bovinoId)');
      },
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
    _currentUid = null;
  }
}
