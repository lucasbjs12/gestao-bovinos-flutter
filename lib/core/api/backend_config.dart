import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Endereco do backend proprio (Node/Express + PostgreSQL), hospedado no
/// Render sob dominio proprio.
class BackendConfig {
  BackendConfig._();

  static const _producao = 'https://api.gestaobovinos.com.br/api/v1';

  /// Base da API, sem barra no final.
  ///
  /// Prioridade: `--dart-define=API_BASE_URL=...` (staging, IP de LAN pra
  /// testar em aparelho físico, etc.) > `--dart-define=USAR_BACKEND_LOCAL=true`
  /// (localhost/emulador) > produção.
  ///
  /// Em dev local, `localhost` só funciona quando o app roda no mesmo host
  /// do backend (web, Windows/macOS/Linux desktop, iOS Simulator). O
  /// emulador Android tem rede isolada -- `10.0.2.2` é o endereço especial
  /// que ele resolve de volta pro host. Dispositivo físico (Android ou iOS)
  /// precisa do IP de LAN do PC (ex. 192.168.x.x) -- use API_BASE_URL pra
  /// isso, ex.: `flutter run --dart-define=API_BASE_URL=http://192.168.0.10:3000/api/v1`.
  static String get baseUrl {
    const baseUrlCustomizada = String.fromEnvironment('API_BASE_URL');
    if (baseUrlCustomizada.isNotEmpty) {
      return baseUrlCustomizada;
    }

    const usarBackendLocal = bool.fromEnvironment('USAR_BACKEND_LOCAL');
    if (usarBackendLocal) {
      if (!kIsWeb && Platform.isAndroid) {
        return 'http://10.0.2.2:3000/api/v1';
      }
      return 'http://localhost:3000/api/v1';
    }
    return _producao;
  }
}
