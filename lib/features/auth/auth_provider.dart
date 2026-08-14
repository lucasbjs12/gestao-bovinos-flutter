import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/db/app_database.dart';
import 'data/app_user.dart';
import 'data/backend_auth_service.dart';

enum AuthStatus { loading, unauthenticated, unverified, authenticated }

class AuthProvider extends ChangeNotifier {
  final BackendAuthService _authService = BackendAuthService();

  AuthStatus _status = AuthStatus.loading;
  String? _error;
  AppUser? _currentUser;
  bool _isAdmin = false;

  // Multi-usuário: fazenda que está sendo visualizada. null (antes de
  // carregar o perfil) ou a própria fazenda por padrão. Um convidado que
  // trocou de fazenda aponta para a fazenda do dono que o convidou.
  String? _fazendaPropriaId;
  String? _fazendaAtivaId;

  AuthStatus get status => _status;
  String? get error => _error;
  AppUser? get currentUser => _currentUser;
  bool get isAdmin => _isAdmin;

  /// Fazenda ativa (escopo de dados). Cai na fazenda própria por padrão.
  String? get fazendaId => _fazendaAtivaId ?? _fazendaPropriaId;

  /// Id da fazenda própria (sempre existe para um usuário autenticado --
  /// o backend cria uma no registro). Não confundir com [fazendaId], que é
  /// a fazenda ativa (pode ser a de outro dono, se o usuário trocou).
  String? get fazendaPropriaId => _fazendaPropriaId;

  /// true quando é o dono da fazenda ativa (pode excluir, gerir membros).
  bool get souDono =>
      _currentUser != null &&
      fazendaId != null &&
      fazendaId == _fazendaPropriaId;

  /// true quando está vendo a fazenda de outro dono (entrou com código).
  bool get ehConvidado => _currentUser != null && !souDono;

  /// Mantido só por compatibilidade de assinatura -- o backend sempre cria
  /// uma fazenda própria no registro, então nunca há usuário "preso" sem
  /// fazenda nenhuma (diferente do modelo antigo de convidado no Firestore).
  bool get precisaEntrarEmFazenda => false;

  static String _chaveFazenda(String uid) => 'fazenda_ativa_$uid';
  static String _chaveVinculos(String uid) => 'fazendas_membro_$uid';

  AuthProvider() {
    _iniciar();
  }

  Future<void> _iniciar() async {
    if (!await _authService.estaLogado()) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    await _carregarSessao();
  }

  Future<void> _carregarSessao({bool tentouRefresh = false}) async {
    try {
      final perfil = await _authService.me();
      _currentUser = AppUser(
        uid: perfil.usuario.id,
        email: perfil.usuario.email,
        displayName: perfil.usuario.nome,
      );
      _isAdmin = perfil.usuario.isAdmin;
      _fazendaPropriaId = perfil.fazendaPropria?.id;

      if (perfil.usuario.emailVerificado) {
        final prefs = await SharedPreferences.getInstance();
        _fazendaAtivaId = prefs.getString(_chaveFazenda(_currentUser!.uid));

        if (fazendaId != null) {
          await AppDatabase.instance.instanceFor(fazendaId);
        }
        _status = AuthStatus.authenticated;
      } else {
        _fazendaAtivaId = null;
        _status = AuthStatus.unverified;
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401 && !tentouRefresh) {
        final sessao = await _authService.refresh().catchError((_) => null);
        if (sessao != null) {
          await _carregarSessao(tentouRefresh: true);
          return;
        }
      }
      await _authService.logout();
      await AppDatabase.instance.close();
      _currentUser = null;
      _fazendaPropriaId = null;
      _fazendaAtivaId = null;
      _status = AuthStatus.unauthenticated;
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Fazendas de outros donos às quais este usuário já ingressou (cache local
  /// para trocar sem precisar de um novo código). Cada item: (id, nome).
  Future<List<({String id, String nome})>> fazendasVinculadas() async {
    final uid = currentUser?.uid;
    if (uid == null) return [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_chaveVinculos(uid)) ?? [];
    return raw.map((e) {
      final i = e.indexOf('|');
      final id = i < 0 ? e : e.substring(0, i);
      final nome = i < 0 ? '' : e.substring(i + 1);
      return (id: id, nome: nome);
    }).toList();
  }

  Future<void> _registrarVinculo(
    String uid,
    String fazendaId,
    String? nome,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final chave = _chaveVinculos(uid);
    final atual = prefs.getStringList(chave) ?? [];
    atual.removeWhere((e) => e == fazendaId || e.startsWith('$fazendaId|'));
    atual.add('$fazendaId|${nome ?? ''}');
    await prefs.setStringList(chave, atual);
  }

  Future<void> removerVinculo(String fazendaId) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final chave = _chaveVinculos(uid);
    final atual = prefs.getStringList(chave) ?? [];
    atual.removeWhere((e) => e == fazendaId || e.startsWith('$fazendaId|'));
    await prefs.setStringList(chave, atual);
    if (_fazendaAtivaId == fazendaId) await voltarParaMinhaFazenda();
  }

  /// Entra numa fazenda (própria ou de um dono que convidou). Persiste a
  /// escolha e dispara a troca de escopo no restante do app.
  Future<void> entrarNaFazenda(String novoFazendaId, {String? nome}) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (novoFazendaId == _fazendaPropriaId) {
      await prefs.remove(_chaveFazenda(uid));
      _fazendaAtivaId = null;
    } else {
      await prefs.setString(_chaveFazenda(uid), novoFazendaId);
      _fazendaAtivaId = novoFazendaId;
      await _registrarVinculo(uid, novoFazendaId, nome);
    }
    notifyListeners();
  }

  Future<void> voltarParaMinhaFazenda() async {
    if (_fazendaPropriaId != null) await entrarNaFazenda(_fazendaPropriaId!);
  }

  Future<bool> login(String email, String senha) async {
    _error = null;
    try {
      await _authService.login(email: email, senha: senha);
      await _carregarSessao();
      return true;
    } on ApiException catch (e) {
      _error = _mensagemErroLogin(e);
      notifyListeners();
      return false;
    } catch (e) {
      _error = _mensagemErroConexao(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> cadastrar(String nomeFazenda, String email, String senha) =>
      _cadastrar(nomeFazenda, email, senha, nomeFazenda: nomeFazenda);

  /// Cadastro de convidado: mesma criação de conta; o backend cria uma
  /// fazenda própria automaticamente (fica sem uso até ele entrar com um
  /// código), sem opção de nomeá-la aqui.
  Future<bool> cadastrarConvidado(String nome, String email, String senha) =>
      _cadastrar(nome, email, senha);

  Future<bool> _cadastrar(
    String nome,
    String email,
    String senha, {
    String? nomeFazenda,
  }) async {
    _error = null;
    try {
      await _authService.registrar(
        nome: nome,
        email: email,
        senha: senha,
        nomeFazenda: nomeFazenda,
      );
      await _carregarSessao();
      return true;
    } on ApiException catch (e) {
      _error = _mensagemErroCadastro(e);
      notifyListeners();
      return false;
    } catch (e) {
      _error = _mensagemErroConexao(e);
      notifyListeners();
      return false;
    }
  }

  /// Recarrega o perfil depois que o usuario abre o link recebido por e-mail.
  Future<bool> verificarEmail() async {
    await _carregarSessao();
    return _status == AuthStatus.authenticated;
  }

  Future<void> reenviarVerificacao() => _authService.reenviarVerificacao();

  Future<void> recuperarSenha(String email) async {
    await _authService.esqueciSenha(email: email);
  }

  Future<void> logout() async {
    await _authService.logout();
    await AppDatabase.instance.close();
    _currentUser = null;
    _fazendaPropriaId = null;
    _fazendaAtivaId = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> atualizarNomeFazenda(String nome) async {
    if (_fazendaPropriaId == null) return false;
    try {
      await ApiClient().patch(
        '/fazendas/$_fazendaPropriaId',
        corpo: {'nome': nome},
      );
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
    try {
      await _authService.alterarSenha(
        senhaAtual: senhaAtual,
        novaSenha: novaSenha,
      );
      return null;
    } on ApiException catch (e) {
      if (e.statusCode == 401) return 'Senha atual incorreta.';
      return 'Erro: ${e.message}';
    } catch (e) {
      return _mensagemErroConexao(e);
    }
  }

  /// Apenas verifica a senha — não altera nada. Retorna null em sucesso.
  Future<String?> reautenticar(String senha) async {
    final email = _currentUser?.email;
    if (email == null) return 'Usuário não encontrado.';
    try {
      await _authService.login(email: email, senha: senha);
      return null;
    } on ApiException catch (e) {
      if (e.statusCode == 401) return 'Senha incorreta.';
      return 'Erro ao verificar senha: ${e.message}';
    } catch (e) {
      return _mensagemErroConexao(e);
    }
  }

  /// Exclui a conta (o backend cuida de apagar a fazenda própria e todos os
  /// dados dela em cascata numa transaction). Retorna null em sucesso.
  Future<String?> excluirConta(String senha) async {
    try {
      await _authService.excluirConta(senha: senha);
      await AppDatabase.instance.close();
      _currentUser = null;
      _fazendaPropriaId = null;
      _fazendaAtivaId = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      if (e.statusCode == 401) return 'Senha incorreta.';
      return 'Erro: ${e.message}';
    } catch (e) {
      return _mensagemErroConexao(e);
    }
  }

  String _mensagemErroConexao(Object erro) {
    if (kDebugMode) {
      return 'Sem conexão com o servidor. Detalhe: $erro';
    }
    return 'Sem conexão com o servidor.';
  }

  String _mensagemErroLogin(ApiException e) {
    if (e.statusCode == 401) return 'E-mail ou senha inválidos.';
    return 'Erro ao entrar: ${e.message}';
  }

  String _mensagemErroCadastro(ApiException e) {
    if (e.statusCode == 409) return 'Este e-mail já está cadastrado.';
    if (e.statusCode == 422) return e.message;
    return 'Erro ao criar conta: ${e.message}';
  }
}
