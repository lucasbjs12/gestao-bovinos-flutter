import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class Convite {
  final String codigo;
  final String fazendaId;
  final String papel;
  final String? criadoPorNome;
  final DateTime expiraEm;
  final bool usado;

  const Convite({
    required this.codigo,
    required this.fazendaId,
    required this.papel,
    this.criadoPorNome,
    required this.expiraEm,
    required this.usado,
  });

  bool get expirado => DateTime.now().isAfter(expiraEm);
  bool get valido => !usado && !expirado;

  // Sem caracteres ambíguos (0/O, 1/I) para ditar por telefone/WhatsApp.
  static const _alfabeto = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String gerarCodigo() {
    final rnd = Random.secure();
    final sufixo = List.generate(
      6,
      (_) => _alfabeto[rnd.nextInt(_alfabeto.length)],
    ).join();
    return 'BOV-$sufixo';
  }

  factory Convite.fromMap(String codigo, Map<String, dynamic> m) => Convite(
        codigo: codigo,
        fazendaId: m['fazendaId'] as String? ?? '',
        papel: m['papel'] as String? ?? 'capataz',
        criadoPorNome: m['criadoPorNome'] as String?,
        expiraEm: (m['expiraEm'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        usado: m['usado'] as bool? ?? false,
      );
}
