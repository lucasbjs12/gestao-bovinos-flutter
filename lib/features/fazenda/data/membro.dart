enum PapelMembro { dono, convidado }

PapelMembro papelFromString(String? s) =>
    s == 'dono' ? PapelMembro.dono : PapelMembro.convidado;

class Membro {
  final String uid;
  final PapelMembro papel;
  final String? nome;

  const Membro({required this.uid, required this.papel, this.nome});

  bool get ehDono => papel == PapelMembro.dono;

  factory Membro.fromMap(String uid, Map<String, dynamic> m) => Membro(
        uid: uid,
        papel: papelFromString(m['papel'] as String?),
        nome: m['nome'] as String?,
      );

  /// Formato do backend próprio: `{usuarioId, papel, nome, usuario:{...}}`.
  factory Membro.fromBackend(Map<String, dynamic> m) => Membro(
        uid: m['usuarioId'] as String,
        papel: papelFromString(m['papel'] as String?),
        nome: (m['nome'] as String?) ??
            ((m['usuario'] as Map<String, dynamic>?)?['nome'] as String?),
      );
}
