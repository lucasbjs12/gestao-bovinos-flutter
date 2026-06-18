class MovimentacaoInvernada {
  final int? id;
  final int bovinoId;
  final String data;
  final int? dataMillis;
  final int? invernadaAnteriorId;
  final int? novaInvernadaId;
  final String? responsavel;
  final String? observacoes;

  const MovimentacaoInvernada({
    this.id,
    required this.bovinoId,
    required this.data,
    this.dataMillis,
    this.invernadaAnteriorId,
    this.novaInvernadaId,
    this.responsavel,
    this.observacoes,
  });

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'bovinoId': bovinoId,
      'data': data,
      'dataMillis': dataMillis,
      'invernadaAnteriorId': invernadaAnteriorId,
      'novaInvernadaId': novaInvernadaId,
      'responsavel': responsavel,
      'observacoes': observacoes,
    };
    if (id != null) m['id'] = id;
    return m;
  }

  factory MovimentacaoInvernada.fromMap(Map<String, dynamic> m) {
    return MovimentacaoInvernada(
      id: m['id'] as int?,
      bovinoId: m['bovinoId'] as int,
      data: m['data'] as String? ?? '',
      dataMillis: m['dataMillis'] as int?,
      invernadaAnteriorId: m['invernadaAnteriorId'] as int?,
      novaInvernadaId: m['novaInvernadaId'] as int?,
      responsavel: m['responsavel'] as String?,
      observacoes: m['observacoes'] as String?,
    );
  }
}

/// Projeção para o histórico de movimentações (JOIN com bovinos e invernadas)
class MovimentacaoResumo {
  final int id;
  final String bovinoNome;
  final String data;
  final String? invernadaAnterior;
  final String? novaInvernada;
  final String? responsavel;
  final String? observacoes;

  const MovimentacaoResumo({
    required this.id,
    required this.bovinoNome,
    required this.data,
    this.invernadaAnterior,
    this.novaInvernada,
    this.responsavel,
    this.observacoes,
  });

  factory MovimentacaoResumo.fromMap(Map<String, dynamic> m) {
    return MovimentacaoResumo(
      id: m['id'] as int,
      bovinoNome: m['bovinoNome'] as String? ?? 'Bovino',
      data: m['data'] as String? ?? '',
      invernadaAnterior: m['invernadaAnterior'] as String?,
      novaInvernada: m['novaInvernada'] as String?,
      responsavel: m['responsavel'] as String?,
      observacoes: m['observacoes'] as String?,
    );
  }
}
