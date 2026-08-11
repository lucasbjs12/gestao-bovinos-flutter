import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Endereco do backend proprio (Node/Express + PostgreSQL).
///
/// Nao existe um padrao de config no projeto ainda (sem .env, sem
/// --dart-define) -- por enquanto e uma constante simples, trocada aqui
/// quando o deploy no Railway estiver pronto (ver backend/README.md).
class BackendConfig {
  BackendConfig._();

  /// Base da API, sem barra no final. Troque para a URL do Railway em
  /// producao (ex: `https://gestaobovinos-backend.up.railway.app/api/v1`).
  ///
  /// Em dev local, `localhost` só funciona quando o app roda no mesmo host
  /// do backend (web, Windows/macOS/Linux desktop, iOS Simulator). O
  /// emulador Android tem rede isolada -- `10.0.2.2` é o endereço especial
  /// que ele resolve de volta pro host. Dispositivo físico (Android ou
  /// iOS) precisa do IP de LAN do PC (ex. 192.168.x.x), que nenhuma dessas
  /// constantes cobre -- troque manualmente aqui se for testar em aparelho.
  static String get baseUrl {
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api/v1';
    }
    return 'http://localhost:3000/api/v1';
  }
}
