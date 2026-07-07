import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Registro imutável do diário de atividades: quem fez o quê e quando.
/// Base da auditoria do multi-usuário (dono acompanha o trabalho do capataz).
class Atividade {
  final int? id;
  final String syncId;
  final String autorUid;
  final String? autorNome;
  final String acao;
  final String descricao;
  final int dataMillis;

  const Atividade({
    this.id,
    required this.syncId,
    required this.autorUid,
    this.autorNome,
    required this.acao,
    required this.descricao,
    required this.dataMillis,
  });

  static Atividade criar({
    required String autorUid,
    String? autorNome,
    required String acao,
    required String descricao,
  }) =>
      Atividade(
        syncId: _uuid.v4(),
        autorUid: autorUid,
        autorNome: autorNome,
        acao: acao,
        descricao: descricao,
        dataMillis: DateTime.now().millisecondsSinceEpoch,
      );

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'syncId': syncId,
      'autorUid': autorUid,
      'autorNome': autorNome,
      'acao': acao,
      'descricao': descricao,
      'dataMillis': dataMillis,
    };
    if (id != null) m['id'] = id;
    return m;
  }

  factory Atividade.fromMap(Map<String, dynamic> m) => Atividade(
        id: m['id'] as int?,
        syncId: m['syncId'] as String? ?? '',
        autorUid: m['autorUid'] as String? ?? '',
        autorNome: m['autorNome'] as String?,
        acao: m['acao'] as String? ?? '',
        descricao: m['descricao'] as String? ?? '',
        dataMillis: m['dataMillis'] as int? ?? 0,
      );
}
