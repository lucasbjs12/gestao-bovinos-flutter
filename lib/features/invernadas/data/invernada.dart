import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Invernada {
  final int? id;
  final String syncId;
  final String descricao;
  final String? urlFoto;
  final String? observacoes;

  // Transientes — preenchidos via JOIN
  final int quantidadeBovinos;
  final String? categoriasBovinos;

  const Invernada({
    this.id,
    required this.syncId,
    required this.descricao,
    this.urlFoto,
    this.observacoes,
    this.quantidadeBovinos = 0,
    this.categoriasBovinos,
  });

  static Invernada criar({required String descricao}) {
    return Invernada(syncId: _uuid.v4(), descricao: descricao);
  }

  Invernada copyWith({int? id}) {
    return Invernada(
      id: id ?? this.id,
      syncId: syncId,
      descricao: descricao,
      urlFoto: urlFoto,
      observacoes: observacoes,
      quantidadeBovinos: quantidadeBovinos,
      categoriasBovinos: categoriasBovinos,
    );
  }

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'syncId': syncId,
      'descricao': descricao,
      'urlFoto': urlFoto,
      'observacoes': observacoes,
    };
    if (id != null) m['id'] = id;
    return m;
  }

  factory Invernada.fromMap(Map<String, dynamic> m) {
    return Invernada(
      id: m['id'] as int?,
      syncId: m['syncId'] as String? ?? _uuid.v4(),
      descricao: m['descricao'] as String? ?? '',
      urlFoto: m['urlFoto'] as String?,
      observacoes: m['observacoes'] as String?,
      quantidadeBovinos: (m['quantidadeBovinos'] as int?) ?? 0,
      categoriasBovinos: m['categoriasBovinos'] as String?,
    );
  }
}
