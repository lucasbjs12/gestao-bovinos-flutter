import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'backend_config.dart';
import 'token_storage.dart';

/// Cliente HTTP fino para o backend proprio. Decodifica o envelope padrao
/// (`{success, message, data}`) e converte erro em [ApiException].
///
/// Faz refresh automatico de token em 401: o access token dura só 15
/// minutos (`JWT_ACCESS_EXPIRES_IN` no backend), entao qualquer sessao mais
/// longa que isso -- inclusive o polling de sync em segundo plano -- bateria
/// nisso o tempo todo se cada chamador tivesse que tratar na mao. Chamadas
/// concorrentes compartilham a mesma renovacao em andamento (nao dispara
/// duas ao mesmo tempo, o que invalidaria uma a outra: o backend rotaciona
/// o refresh token a cada uso).
class ApiClient {
  ApiClient({http.Client? httpClient, TokenStorage? tokenStorage, String? baseUrl})
    : _client = httpClient ?? http.Client(),
      _tokenStorage = tokenStorage ?? TokenStorage(),
      _baseUrl = baseUrl ?? BackendConfig.baseUrl;

  final http.Client _client;
  final TokenStorage _tokenStorage;
  final String _baseUrl;

  Future<String?>? _refreshEmAndamento;

  Future<dynamic> get(String caminho, {bool autenticado = true}) =>
      _enviar('GET', caminho, autenticado: autenticado);

  Future<dynamic> post(String caminho, {Object? corpo, bool autenticado = true}) =>
      _enviar('POST', caminho, corpo: corpo, autenticado: autenticado);

  Future<dynamic> put(String caminho, {Object? corpo, bool autenticado = true}) =>
      _enviar('PUT', caminho, corpo: corpo, autenticado: autenticado);

  Future<dynamic> patch(String caminho, {Object? corpo, bool autenticado = true}) =>
      _enviar('PATCH', caminho, corpo: corpo, autenticado: autenticado);

  Future<dynamic> delete(String caminho, {Object? corpo, bool autenticado = true}) =>
      _enviar('DELETE', caminho, corpo: corpo, autenticado: autenticado);

  Future<dynamic> _enviar(
    String metodo,
    String caminho, {
    Object? corpo,
    required bool autenticado,
    bool tentandoNovamente = false,
  }) async {
    final uri = Uri.parse('$_baseUrl$caminho');
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (autenticado) {
      final token = await _tokenStorage.lerAccessToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }

    final corpoCodificado = corpo == null ? null : jsonEncode(corpo);

    late final http.Response resposta;
    switch (metodo) {
      case 'GET':
        resposta = await _client.get(uri, headers: headers);
        break;
      case 'POST':
        resposta = await _client.post(uri, headers: headers, body: corpoCodificado);
        break;
      case 'PUT':
        resposta = await _client.put(uri, headers: headers, body: corpoCodificado);
        break;
      case 'PATCH':
        resposta = await _client.patch(uri, headers: headers, body: corpoCodificado);
        break;
      case 'DELETE':
        resposta = await _client.delete(uri, headers: headers, body: corpoCodificado);
        break;
      default:
        throw ArgumentError('Metodo HTTP nao suportado: $metodo');
    }

    // Access token expirado: tenta renovar (uma vez só, pra nao entrar em
    // loop) e repete a mesma chamada com o token novo.
    if (autenticado && resposta.statusCode == 401 && !tentandoNovamente) {
      final novoToken = await _renovarToken();
      if (novoToken != null) {
        return _enviar(
          metodo,
          caminho,
          corpo: corpo,
          autenticado: autenticado,
          tentandoNovamente: true,
        );
      }
    }

    return _tratarResposta(resposta);
  }

  Future<String?> _renovarToken() {
    return _refreshEmAndamento ??= _fazerRefresh().whenComplete(() {
      _refreshEmAndamento = null;
    });
  }

  Future<String?> _fazerRefresh() async {
    final refreshToken = await _tokenStorage.lerRefreshToken();
    if (refreshToken == null) return null;

    try {
      final uri = Uri.parse('$_baseUrl/auth/refresh');
      final resposta = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      final dados = _tratarResposta(resposta) as Map<String, dynamic>;
      final novoAccessToken = dados['accessToken'] as String;
      final novoRefreshToken = dados['refreshToken'] as String;
      await _tokenStorage.salvar(accessToken: novoAccessToken, refreshToken: novoRefreshToken);
      return novoAccessToken;
    } catch (_) {
      // Refresh token tambem invalido/expirado -- sessao morreu de vez.
      // Limpa pra nao ficar tentando renovar com um token morto a cada
      // chamada (AuthProvider percebe no proximo /me e desloga).
      await _tokenStorage.limpar();
      return null;
    }
  }

  dynamic _tratarResposta(http.Response resposta) {
    // 204 No Content: sem corpo pra decodificar.
    if (resposta.statusCode == 204) return null;

    Map<String, dynamic> corpo;
    try {
      corpo = jsonDecode(resposta.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        statusCode: resposta.statusCode,
        message: 'Resposta invalida do servidor (status ${resposta.statusCode})',
      );
    }

    final sucesso = corpo['success'] == true;
    if (!sucesso) {
      final erro = corpo['error'];
      final codigo = erro is Map ? erro['code'] as String? : null;
      throw ApiException(
        statusCode: resposta.statusCode,
        message: corpo['message'] as String? ?? 'Erro desconhecido',
        codigo: codigo,
      );
    }

    return corpo['data'];
  }
}
