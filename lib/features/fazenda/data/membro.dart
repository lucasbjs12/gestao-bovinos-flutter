enum PapelMembro { dono, capataz }

PapelMembro papelFromString(String? s) =>
    s == 'dono' ? PapelMembro.dono : PapelMembro.capataz;

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
}
