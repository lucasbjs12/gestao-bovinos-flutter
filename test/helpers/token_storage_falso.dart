import 'package:gestao_bovinos_app/core/api/token_storage.dart';

/// Dublê em memoria de [TokenStorage] pra teste unitario -- evita depender
/// do plugin de platform channel do flutter_secure_storage em `flutter test`.
class TokenStorageFalso implements TokenStorage {
  String? _accessToken;
  String? _refreshToken;

  @override
  Future<void> salvar({required String accessToken, required String refreshToken}) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  @override
  Future<String?> lerAccessToken() async => _accessToken;

  @override
  Future<String?> lerRefreshToken() async => _refreshToken;

  @override
  Future<void> limpar() async {
    _accessToken = null;
    _refreshToken = null;
  }
}
