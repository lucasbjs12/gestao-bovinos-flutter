class BaixaBovino {
  final int? id;
  final int bovinoId;
  final String motivo;
  final String? observacoes;
  final String dataBaixa;
  final int dataBaixaMillis;

  const BaixaBovino({
    this.id,
    required this.bovinoId,
    required this.motivo,
    this.observacoes,
    required this.dataBaixa,
    required this.dataBaixaMillis,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'bovinoId': bovinoId,
        'motivo': motivo,
        'observacoes': observacoes,
        'dataBaixa': dataBaixa,
        'dataBaixaMillis': dataBaixaMillis,
      };
}

class BovinoBaixado {
  final int id;
  final String syncId;
  final String numeroBrinco;
  final String? nomeAnimal;
  final String? categoria;
  final String? raca;
  final String? foto;
  final int baixaId;
  final String motivo;
  final String? dataBaixa;
  final int? dataBaixaMillis;
  final String? observacoesBaixa;

  const BovinoBaixado({
    required this.id,
    required this.syncId,
    required this.numeroBrinco,
    this.nomeAnimal,
    this.categoria,
    this.raca,
    this.foto,
    required this.baixaId,
    required this.motivo,
    this.dataBaixa,
    this.dataBaixaMillis,
    this.observacoesBaixa,
  });

  factory BovinoBaixado.fromMap(Map<String, dynamic> m) => BovinoBaixado(
        id: m['id'] as int,
        syncId: m['syncId'] as String,
        numeroBrinco: m['numeroBrinco'] as String,
        nomeAnimal: m['nomeAnimal'] as String?,
        categoria: m['categoria'] as String?,
        raca: m['raca'] as String?,
        foto: m['foto'] as String?,
        baixaId: m['baixaId'] as int,
        motivo: m['motivo'] as String,
        dataBaixa: m['dataBaixa'] as String?,
        dataBaixaMillis: m['dataBaixaMillis'] as int?,
        observacoesBaixa: m['observacoesBaixa'] as String?,
      );
}

class BovinoResumoManejo {
  final int id;
  final String syncId;
  final String numeroBrinco;
  final String? nomeAnimal;
  final String? categoria;
  final int? invernadaId;
  final String? invernadaDescricao;
  final int? ultimoManejoMillis;

  const BovinoResumoManejo({
    required this.id,
    required this.syncId,
    required this.numeroBrinco,
    this.nomeAnimal,
    this.categoria,
    this.invernadaId,
    this.invernadaDescricao,
    this.ultimoManejoMillis,
  });

  factory BovinoResumoManejo.fromMap(Map<String, dynamic> m) =>
      BovinoResumoManejo(
        id: m['id'] as int,
        syncId: m['syncId'] as String,
        numeroBrinco: m['numeroBrinco'] as String,
        nomeAnimal: m['nomeAnimal'] as String?,
        categoria: m['categoria'] as String?,
        invernadaId: m['invernadaId'] as int?,
        invernadaDescricao: m['invernadaDescricao'] as String?,
        ultimoManejoMillis: m['ultimoManejoMillis'] as int?,
      );
}
