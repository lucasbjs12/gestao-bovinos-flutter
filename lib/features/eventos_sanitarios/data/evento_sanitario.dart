import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class EventoSanitario {
  final int? id;
  final String syncId;
  final String tipo;
  final String? dataEvento;
  final int? dataEventoMillis;
  final int? invernadaId;
  final String? produtoUtilizado;
  final String? dosagem;
  final String? responsavel;
  final String? observacoes;

  const EventoSanitario({
    this.id,
    required this.syncId,
    required this.tipo,
    this.dataEvento,
    this.dataEventoMillis,
    this.invernadaId,
    this.produtoUtilizado,
    this.dosagem,
    this.responsavel,
    this.observacoes,
  });

  static EventoSanitario criar({required String tipo}) => EventoSanitario(
        syncId: _uuid.v4(),
        tipo: tipo,
      );

  EventoSanitario copyWith({int? id}) => EventoSanitario(
        id: id ?? this.id,
        syncId: syncId,
        tipo: tipo,
        dataEvento: dataEvento,
        dataEventoMillis: dataEventoMillis,
        invernadaId: invernadaId,
        produtoUtilizado: produtoUtilizado,
        dosagem: dosagem,
        responsavel: responsavel,
        observacoes: observacoes,
      );

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'syncId': syncId,
      'tipo': tipo,
      'dataEvento': dataEvento,
      'dataEventoMillis': dataEventoMillis,
      'invernadaId': invernadaId,
      'produtoUtilizado': produtoUtilizado,
      'dosagem': dosagem,
      'responsavel': responsavel,
      'observacoes': observacoes,
    };
    if (id != null) m['id'] = id;
    return m;
  }

  factory EventoSanitario.fromMap(Map<String, dynamic> m) => EventoSanitario(
        id: m['id'] as int?,
        syncId: m['syncId'] as String? ?? _uuid.v4(),
        tipo: m['tipo'] as String? ?? 'Outros',
        dataEvento: m['dataEvento'] as String?,
        dataEventoMillis: m['dataEventoMillis'] as int?,
        invernadaId: m['invernadaId'] as int?,
        produtoUtilizado: m['produtoUtilizado'] as String?,
        dosagem: m['dosagem'] as String?,
        responsavel: m['responsavel'] as String?,
        observacoes: m['observacoes'] as String?,
      );

  static const tipos = [
    'Vacinação',
    'Vermifugação',
    'Medicação',
    'Castração',
    'Banho',
    'Outros',
  ];
}
