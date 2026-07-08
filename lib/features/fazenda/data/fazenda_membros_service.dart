import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'convite.dart';
import 'membro.dart';

/// Gestão de membros e convites de uma fazenda.
///
/// Convites ficam numa coleção de nível superior (`convites/{codigo}`) para
/// que o convidado consiga lê-los antes de virar membro — dentro da fazenda
/// as rules bloqueariam quem ainda não pertence a ela.
class FazendaMembrosService {
  static final _fs = FirebaseFirestore.instance;

  static const conviteValidadeHoras = 48;

  static CollectionReference<Map<String, dynamic>> _membrosCol(String fazendaId) =>
      _fs.collection('fazendas').doc(fazendaId).collection('membros');

  static CollectionReference<Map<String, dynamic>> get _convitesCol =>
      _fs.collection('convites');

  static Future<List<Membro>> listarMembros(String fazendaId) async {
    final snap = await _membrosCol(fazendaId).get();
    return snap.docs.map((d) => Membro.fromMap(d.id, d.data())).toList()
      ..sort((a, b) {
        if (a.ehDono != b.ehDono) return a.ehDono ? -1 : 1;
        return (a.nome ?? '').compareTo(b.nome ?? '');
      });
  }

  static Future<void> removerMembro(String fazendaId, String membroUid) =>
      _membrosCol(fazendaId).doc(membroUid).delete();

  /// Gera um convite de capataz e devolve o código. O dono é sempre o dono da
  /// própria fazenda (fazendaId == uid).
  static Future<String> gerarConvite(String fazendaId) async {
    final nome = FirebaseAuth.instance.currentUser?.displayName ??
        FirebaseAuth.instance.currentUser?.email;
    // Tenta alguns códigos até achar um livre (colisão é improvável).
    for (var i = 0; i < 5; i++) {
      final codigo = Convite.gerarCodigo();
      final ref = _convitesCol.doc(codigo);
      if ((await ref.get()).exists) continue;
      await ref.set({
        'fazendaId': fazendaId,
        'papel': 'capataz',
        'criadoPorNome': nome,
        'expiraEm': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: conviteValidadeHoras)),
        ),
        'usado': false,
        'criadoEm': FieldValue.serverTimestamp(),
      });
      return codigo;
    }
    throw Exception('Não foi possível gerar um código. Tente de novo.');
  }

  /// Lê um convite pelo código (usado pela tela do convidado).
  static Future<Convite?> buscarConvite(String codigo) async {
    final doc = await _convitesCol.doc(codigo.trim().toUpperCase()).get();
    if (!doc.exists) return null;
    return Convite.fromMap(doc.id, doc.data()!);
  }

  /// O convidado entra na fazenda: cria o próprio doc de membro (autorizado
  /// pelas rules quando há convite válido) e marca o convite como usado.
  /// Retorna o fazendaId ingressado.
  static Future<String> aceitarConvite(String codigo) async {
    final normalizado = codigo.trim().toUpperCase();
    final convite = await buscarConvite(normalizado);
    if (convite == null) throw Exception('Código não encontrado.');
    if (convite.usado) throw Exception('Este convite já foi usado.');
    if (convite.expirado) throw Exception('Este convite expirou.');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Faça login para entrar numa fazenda.');
    if (user.uid == convite.fazendaId) {
      throw Exception('Você é o dono desta fazenda.');
    }

    await _membrosCol(convite.fazendaId).doc(user.uid).set({
      'papel': 'capataz',
      'nome': user.displayName ?? user.email,
      'conviteCodigo': normalizado,
      'desde': FieldValue.serverTimestamp(),
    });
    await _convitesCol.doc(normalizado).update({
      'usado': true,
      'usadoPor': user.uid,
    });
    return convite.fazendaId;
  }
}
