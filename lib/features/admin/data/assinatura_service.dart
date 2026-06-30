import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'usuario_assinatura.dart';

class AssinaturaService {
  static final _fs = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _col =>
      _fs.collection('usuarios');

  static Future<UsuarioAssinatura?> buscarUsuario(String uid) async {
    final doc = await _col.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UsuarioAssinatura.fromMap(uid, doc.data()!);
  }

  static Future<UsuarioAssinatura> garantirUsuario(User user) async {
    final doc = await _col.doc(user.uid).get();
    if (doc.exists && doc.data() != null) {
      return UsuarioAssinatura.fromMap(user.uid, doc.data()!);
    }
    final novo = UsuarioAssinatura(
      uid: user.uid,
      nome: user.displayName ?? '',
      email: user.email ?? '',
      isAdmin: false,
      status: StatusAssinatura.pendente,
      criadoEm: DateTime.now(),
    );
    await _col.doc(user.uid).set(novo.toMap());
    return novo;
  }

  static Future<List<UsuarioAssinatura>> listarTodos() async {
    final snap = await _col.orderBy('criadoEm', descending: true).get();
    return snap.docs
        .map((d) => UsuarioAssinatura.fromMap(d.id, d.data()))
        .toList();
  }

  static Future<void> ativar({
    required String uid,
    required String plano,
    required DateTime vencimento,
  }) =>
      _col.doc(uid).update({
        'status': StatusAssinatura.ativo.name,
        'plano': plano,
        'vencimento': Timestamp.fromDate(vencimento),
      });

  static Future<void> bloquear(String uid) =>
      _col.doc(uid).update({'status': StatusAssinatura.bloqueado.name});

  static Future<void> toggleAdmin(String uid, bool isAdmin) =>
      _col.doc(uid).update({'isAdmin': isAdmin});
}
