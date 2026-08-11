import '../../../core/api/api_client.dart';
import '../../../core/api/token_storage.dart';
import 'backend_auth_models.dart';

/// Fala com `/api/v1/auth/*` do backend proprio. Isolado de proposito --
/// ainda NAO esta ligado ao [AuthProvider] nem a nenhuma tela; e a base
/// para a migracao gradual do Firebase Auth pra este backend.
class BackendAuthService {
  BackendAuthService({ApiClient? apiClient, TokenStorage? tokenStorage})
    : _api = apiClient ?? ApiClient(),
      _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _api;
  final TokenStorage _tokenStorage;

  Future<SessaoBackend> registrar({
    required String nome,
    required String email,
    required String senha,
    String? nomeFazenda,
  }) async {
    final dados = await _api.post(
      '/auth/registro',
      corpo: {
        'nome': nome,
        'email': email,
        'senha': senha,
        if (nomeFazenda != null && nomeFazenda.trim().isNotEmpty) 'nomeFazenda': nomeFazenda,
      },
      autenticado: false,
    );
    final sessao = SessaoBackend.fromMap(dados as Map<String, dynamic>);
    await _tokenStorage.salvar(accessToken: sessao.accessToken, refreshToken: sessao.refreshToken);
    return sessao;
  }

  Future<SessaoBackend> login({required String email, required String senha}) async {
    final dados = await _api.post(
      '/auth/login',
      corpo: {'email': email, 'senha': senha},
      autenticado: false,
    );
    final sessao = SessaoBackend.fromMap(dados as Map<String, dynamic>);
    await _tokenStorage.salvar(accessToken: sessao.accessToken, refreshToken: sessao.refreshToken);
    return sessao;
  }

  /// Renova o access token usando o refresh token guardado. Retorna `null`
  /// se nao houver refresh token salvo (usuario nunca logou por aqui).
  Future<SessaoBackend?> refresh() async {
    final refreshTokenAtual = await _tokenStorage.lerRefreshToken();
    if (refreshTokenAtual == null) return null;

    final dados = await _api.post(
      '/auth/refresh',
      corpo: {'refreshToken': refreshTokenAtual},
      autenticado: false,
    );
    final sessao = SessaoBackend.fromMap(dados as Map<String, dynamic>);
    await _tokenStorage.salvar(accessToken: sessao.accessToken, refreshToken: sessao.refreshToken);
    return sessao;
  }

  Future<void> esqueciSenha({required String email}) async {
    await _api.post('/auth/esqueci-senha', corpo: {'email': email}, autenticado: false);
  }

  Future<void> redefinirSenha({required String token, required String novaSenha}) async {
    await _api.post(
      '/auth/redefinir-senha',
      corpo: {'token': token, 'novaSenha': novaSenha},
      autenticado: false,
    );
  }

  Future<void> alterarSenha({required String senhaAtual, required String novaSenha}) async {
    await _api.patch(
      '/auth/senha',
      corpo: {'senhaAtual': senhaAtual, 'novaSenha': novaSenha},
    );
  }

  Future<void> excluirConta({required String senha}) async {
    await _api.delete('/auth/me', corpo: {'senha': senha});
  }

  Future<void> logout() async {
    final refreshTokenAtual = await _tokenStorage.lerRefreshToken();
    if (refreshTokenAtual != null) {
      // Best-effort: mesmo se a chamada falhar (sem rede, token ja expirado),
      // ainda assim limpamos o storage local abaixo.
      try {
        await _api.post(
          '/auth/logout',
          corpo: {'refreshToken': refreshTokenAtual},
          autenticado: false,
        );
      } catch (_) {
        // ignorar -- logout local sempre acontece
      }
    }
    await _tokenStorage.limpar();
  }

  Future<PerfilBackend> me() async {
    final dados = await _api.get('/auth/me');
    return PerfilBackend.fromMap(dados as Map<String, dynamic>);
  }

  Future<bool> estaLogado() async {
    return (await _tokenStorage.lerAccessToken()) != null;
  }
}
