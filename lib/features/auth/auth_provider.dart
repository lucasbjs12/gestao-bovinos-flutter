import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';

enum AuthStatus { loading, unauthenticated, unverified, authenticated }

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthStatus _status = AuthStatus.loading;
  String? _error;

  AuthStatus get status => _status;
  String? get error => _error;
  User? get currentUser => _auth.currentUser;

  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    if (user == null) {
      await AppDatabase.instance.close();
      _status = AuthStatus.unauthenticated;
    } else if (!user.emailVerified) {
      _status = AuthStatus.unverified;
    } else {
      // Banco já está aberto (ou será aberto na primeira query) com UID correto.
      await AppDatabase.instance.instanceFor(user.uid);
      _status = AuthStatus.authenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String senha) async {
    _error = null;
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: senha);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mensagemErroLogin(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> cadastrar(String nomeFazenda, String email, String senha) async {
    _error = null;
    _auth.setLanguageCode('pt');
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: senha,
      );
      final user = result.user;
      if (user != null) {
        await user.updateDisplayName(nomeFazenda);
        await user.sendEmailVerification();
      }
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mensagemErroCadastro(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> verificarEmail() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final atualizado = _auth.currentUser;
    if (atualizado != null && atualizado.emailVerified) {
      _status = AuthStatus.authenticated;
      await AppDatabase.instance.instanceFor(atualizado.uid);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> reenviarVerificacao() async {
    _auth.setLanguageCode('pt');
    await _auth.currentUser?.sendEmailVerification();
  }

  Future<void> recuperarSenha(String email) async {
    _auth.setLanguageCode('pt');
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<bool> atualizarNomeFazenda(String nome) async {
    try {
      await currentUser?.updateDisplayName(nome);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Retorna null em sucesso, ou mensagem de erro.
  Future<String?> alterarSenha({
    required String senhaAtual,
    required String novaSenha,
  }) async {
    final user = currentUser;
    if (user == null || user.email == null) return 'Usuário não encontrado.';
    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: senhaAtual,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(novaSenha);
      return null;
    } on FirebaseAuthException catch (e) {
      return switch (e.code) {
        'wrong-password' || 'invalid-credential' => 'Senha atual incorreta.',
        'weak-password' => 'Senha fraca. Use pelo menos 6 caracteres.',
        _ => 'Erro: ${e.message}',
      };
    }
  }

  /// Re-autentica e deleta a conta. Limpeza de Firestore deve ser feita pelo caller antes.
  /// Retorna null em sucesso, ou mensagem de erro.
  Future<String?> excluirConta(String senha) async {
    final user = currentUser;
    if (user == null || user.email == null) return 'Usuário não encontrado.';
    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: senha,
      );
      await user.reauthenticateWithCredential(cred);
      await AppDatabase.instance.close();
      await user.delete();
      return null;
    } on FirebaseAuthException catch (e) {
      return switch (e.code) {
        'wrong-password' || 'invalid-credential' => 'Senha incorreta.',
        _ => 'Erro: ${e.message}',
      };
    }
  }

  String _mensagemErroLogin(FirebaseAuthException e) {
    switch (e.code) {
      case 'network-request-failed':
        return 'Sem conexão com a internet.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha inválidos.';
      default:
        return 'Erro ao entrar: ${e.message}';
    }
  }

  String _mensagemErroCadastro(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado.';
      case 'weak-password':
        return 'Senha fraca. Use pelo menos 6 caracteres.';
      default:
        return 'Erro ao criar conta: ${e.message}';
    }
  }
}
