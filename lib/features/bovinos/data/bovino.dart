import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum BovinoOrdem { brinco, nome, categoria, invernada, peso }

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
      invernadaDescricao: m['invernadaDescricao'] as String?,
      ultimoManejoMillis: m['ultimoManejoMillis'] as int?,
    );
  }
}
