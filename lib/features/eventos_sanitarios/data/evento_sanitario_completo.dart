/// Resultado de JOIN: evento + descricao da invernada + lista de bovinos.
class EventoSanitarioCompleto {
  final int id;
  final String syncId;
  final String tipo;
  final String? dataEvento;
  final int? dataEventoMillis;
  final int? invernadaId;
  final String? invernadaDescricao;
  final String? produtoUtilizado;
  final String? dosagem;
  final String? responsavel;
  final String? observacoes;
  // CSV vindos de GROUP_CONCAT
  final String? bovinoIds;
  final String? bovinoNomes;

  const EventoSanitarioCompleto({
    required this.id,
    required this.syncId,
    required this.tipo,
    this.dataEvento,
    this.dataEventoMillis,
    this.invernadaId,
    this.invernadaDescricao,
    this.produtoUtilizado,
    this.dosagem,
    this.responsavel,
    this.observacoes,
    this.bovinoIds,
    this.bovinoNomes,
  });

  List<int> get bovinoIdsList {
    if (bovinoIds == null || bovinoIds!.isEmpty) return [];
    return bovinoIds!
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();
  }

  List<String> get bovinoNomesList {
    if (bovinoNomes == null || bovinoNomes!.isEmpty) return [];
    return bovinoNomes!.split(',').map((s) => s.trim()).toList();
  }

  int get quantidadeBovinos => bovinoIdsList.length;

  factory EventoSanitarioCompleto.fromMap(Map<String, dynamic> m) =>
      EventoSanitarioCompleto(
        id: m['id'] as int,
        syncId: m['syncId'] as String? ?? '',
        tipo: m['tipo'] as String? ?? 'Outros',
        dataEvento: m['dataEvento'] as String?,
        dataEventoMillis: m['dataEventoMillis'] as int?,
        invernadaId: m['invernadaId'] as int?,
        invernadaDescricao: m['invernadaDescricao'] as String?,
        produtoUtilizado: m['produtoUtilizado'] as String?,
        dosagem: m['dosagem'] as String?,
        responsavel: m['responsavel'] as String?,
        observacoes: m['observacoes'] as String?,
        bovinoIds: m['bovinoIds'] as String?,
        bovinoNomes: m['bovinoNomes'] as String?,
      );
}
