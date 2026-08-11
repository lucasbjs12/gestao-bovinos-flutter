import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Endereco do backend proprio (Node/Express + PostgreSQL), hospedado no
/// Render.
///
/// Nao existe um padrao de config no projeto ainda (sem .env, sem
/// --dart-define) -- por enquanto e uma constante simples. Quando
/// `api.gestaobovinos.com.br` estiver com o DNS propagado, troque
/// `_producao` para usar o dominio proprio em vez do `.onrender.com`.
class BackendConfig {
  BackendConfig._();

  static const _producao = 'https://gestao-bovinos-flutter.onrender.com/api/v1';

  /// Base da API, sem barra no final.
  ///
  /// Em dev local, `localhost` só funciona quando o app roda no mesmo host
  /// do backend (web, Windows/macOS/Linux desktop, iOS Simulator). O
  /// emulador Android tem rede isolada -- `10.0.2.2` é o endereço especial
  /// que ele resolve de volta pro host. Dispositivo físico (Android ou
  /// iOS) precisa do IP de LAN do PC (ex. 192.168.x.x), que nenhuma dessas
  /// constantes cobre -- troque manualmente aqui se for testar em aparelho.
  static String get baseUrl {
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
