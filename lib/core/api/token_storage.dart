import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda accessToken/refreshToken no Keychain (iOS) / Keystore (Android)
/// via flutter_secure_storage -- diferente do SharedPreferences usado pra
/// prefs comuns no resto do app, porque um refresh token e uma credencial
/// de longa duracao (equivalente a uma senha), nao um dado de UI.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _chaveAccessToken = 'backend_access_token';
  static const _chaveRefreshToken = 'backend_refresh_token';

  Future<void> salvar({required String accessToken, required String refreshToken}) async {
    await Future.wait([
      _storage.write(key: _chaveAccessToken, value: accessToken),
      _storage.write(key: _chaveRefreshToken, value: refreshToken),
    ]);
  }

  Future<String?> lerAccessToken() => _storage.read(key: _chaveAccessToken);

  Future<String?> lerRefreshToken() => _storage.read(key: _chaveRefreshToken);

  Future<void> limpar() async {
    await Future.wait([
      _storage.delete(key: _chaveAccessToken),
      _storage.delete(key: _chaveRefreshToken),
    ]);
  }
}
