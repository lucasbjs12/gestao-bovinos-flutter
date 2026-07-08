import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Garante que o dono tem seu doc de membro na própria fazenda
/// (fazendas/{uid}/membros/{uid}, papel 'dono'). Idempotente — roda a cada
/// abertura autenticada e nunca lança: sem ele o app atual segue funcionando,
/// pois as rules reconhecem o dono pela construção fazendaId == uid.
class MembroService {
  static Future<void> garantirDono(String uid) async {
    try {
      final ref = FirebaseFirestore.instance
          .collection('fazendas')
          .doc(uid)
          .collection('membros')
          .doc(uid);
      final doc = await ref.get();
      if (doc.exists) return;

      final user = FirebaseAuth.instance.currentUser;
      await ref.set({
        'papel': 'dono',
        'nome': user?.displayName ?? user?.email,
        'desde': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
