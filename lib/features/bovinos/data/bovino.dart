import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum BovinoOrdem { brinco, nome, categoria, invernada, peso }

/// Paleta fixa de destaque visual (ex: novilhas vacinadas com produto
/// especial) -- mesmos valores do enum `CorDestaque` do backend, pra não
/// depender de hex livre nem cada fazenda usar uma cor diferente.
enum CorDestaque {
  amarelo,
  azul,
  verde,
  vermelho,
  roxo,
  laranja;

  static CorDestaque? fromNome(String? nome) {
    if (nome == null) return null;
    for (final c in CorDestaque.values) {
      if (c.name == nome) return c;
    }
    return null;
  }
}

class Bovino {
  final int? id;
  final String syncId;
  final String? nomeAnimal;
  final String? codigoEpc;
  final String? codigoInterno;
  final String numeroBrinco;
  final String? raca;
  final String? dataNascimento;
  final int? dataNascimentoMillis;
  final double? pesoAtualKg;
  final String? pelagem;
  final String? sexo;
  final String? categoria;
  final String status;
  final String? origem;
  final String? observacoes;
  final String? foto;
  final int? invernadaId;
  final int? idMae;
  final int estaDeCria;
  final CorDestaque? corDestaque;
  final String? rotuloDestaque;

  // Transient — populated via JOIN/subquery, not DB columns
  final String? invernadaDescricao;
  final int? ultimoManejoMillis;

  const Bovino({
    this.id,
    required this.syncId,
    this.nomeAnimal,
    this.codigoEpc,
    this.codigoInterno,
    required this.numeroBrinco,
    this.raca,
    this.dataNascimento,
    this.dataNascimentoMillis,
    this.pesoAtualKg,
    this.pelagem,
    this.sexo,
    this.categoria,
    this.status = 'Ativo',
    this.origem,
    this.observacoes,
    this.foto,
    this.invernadaId,
    this.idMae,
    this.estaDeCria = 0,
    this.corDestaque,
    this.rotuloDestaque,
    this.invernadaDescricao,
    this.ultimoManejoMillis,
  });

  Bovino copyWith({
    int? id,
    String? foto,
    int? idMae,
    bool clearIdMae = false,
    int? invernadaId,
    bool clearInvernadaId = false,
    CorDestaque? corDestaque,
    String? rotuloDestaque,
    bool clearDestaque = false,
  }) {
    return Bovino(
      id: id ?? this.id,
      syncId: syncId,
      nomeAnimal: nomeAnimal,
      codigoEpc: codigoEpc,
      codigoInterno: codigoInterno,
      numeroBrinco: numeroBrinco,
      raca: raca,
      dataNascimento: dataNascimento,
      dataNascimentoMillis: dataNascimentoMillis,
      pesoAtualKg: pesoAtualKg,
      pelagem: pelagem,
      sexo: sexo,
      categoria: categoria,
      status: status,
      origem: origem,
      observacoes: observacoes,
      foto: foto ?? this.foto,
      invernadaId: clearInvernadaId ? null : (invernadaId ?? this.invernadaId),
      idMae: clearIdMae ? null : (idMae ?? this.idMae),
      estaDeCria: estaDeCria,
      corDestaque: clearDestaque ? null : (corDestaque ?? this.corDestaque),
      rotuloDestaque: clearDestaque
          ? null
          : (rotuloDestaque ?? this.rotuloDestaque),
      // transient fields not in copyWith
    );
  }

  static Bovino criar({required String numeroBrinco}) {
    return Bovino(
      syncId: _uuid.v4(),
      numeroBrinco: numeroBrinco,
    );
  }

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'syncId': syncId,
      'nomeAnimal': nomeAnimal,
      'codigoEpc': codigoEpc,
      'codigoInterno': codigoInterno,
      'numeroBrinco': numeroBrinco,
      'raca': raca,
      'dataNascimento': dataNascimento,
      'dataNascimentoMillis': dataNascimentoMillis,
      'pesoAtualKg': pesoAtualKg,
      'pelagem': pelagem,
      'sexo': sexo,
      'categoria': categoria,
      'status': status,
      'origem': origem,
      'observacoes': observacoes,
      'foto': foto,
      'invernadaId': invernadaId,
      'idMae': idMae,
      'estaDeCria': estaDeCria,
      'corDestaque': corDestaque?.name,
      'rotuloDestaque': rotuloDestaque,
    };
    if (id != null) m['id'] = id;
    return m;
  }

  factory Bovino.fromMap(Map<String, dynamic> m) {
    return Bovino(
      id: m['id'] as int?,
      syncId: m['syncId'] as String? ?? _uuid.v4(),
      nomeAnimal: m['nomeAnimal'] as String?,
      codigoEpc: m['codigoEpc'] as String?,
      codigoInterno: m['codigoInterno'] as String?,
      numeroBrinco: m['numeroBrinco'] as String? ?? '',
      raca: m['raca'] as String?,
      dataNascimento: m['dataNascimento'] as String?,
      dataNascimentoMillis: m['dataNascimentoMillis'] as int?,
      pesoAtualKg: (m['pesoAtualKg'] as num?)?.toDouble(),
      pelagem: m['pelagem'] as String?,
      sexo: m['sexo'] as String?,
      categoria: m['categoria'] as String?,
      status: m['status'] as String? ?? 'Ativo',
      origem: m['origem'] as String?,
      observacoes: m['observacoes'] as String?,
      foto: m['foto'] as String?,
      invernadaId: m['invernadaId'] as int?,
      idMae: m['idMae'] as int?,
      estaDeCria: m['estaDeCria'] as int? ?? 0,
      corDestaque: CorDestaque.fromNome(m['corDestaque'] as String?),
      rotuloDestaque: m['rotuloDestaque'] as String?,
      invernadaDescricao: m['invernadaDescricao'] as String?,
      ultimoManejoMillis: m['ultimoManejoMillis'] as int?,
    );
  }
}
