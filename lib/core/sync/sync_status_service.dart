import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

enum SyncEstado { sincronizado, sincronizando, offline, pendente }

class SyncStatusService extends ChangeNotifier {
  SyncEstado _estado = SyncEstado.sincronizado;
  SyncEstado get estado => _estado;

  int _pendencias = 0;
  int get pendencias => _pendencias;

  bool _online = true;
  bool get online => _online;
  bool _iniciado = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// Chamado por quem monta a tela (app.dart) pra saber quando tentar
  /// esvaziar a fila de pendências assim que a conexão voltar, em vez de
  /// esperar o próximo ciclo do polling (até 45s).
  VoidCallback? aoReconectar;

  void iniciar() {
    if (_iniciado) return;
    _iniciado = true;

    Connectivity().checkConnectivity().then((results) {
      _online = results.any((r) => r != ConnectivityResult.none);
      if (!_online) _setEstado(SyncEstado.offline);
    });

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final agora = results.any((r) => r != ConnectivityResult.none);
      if (agora == _online) return;
      _online = agora;
      if (!_online) {
        _setEstado(SyncEstado.offline);
      } else {
        _verificarPendencias();
        aoReconectar?.call();
      }
    });
  }

  /// Chamado pelos remote repositories DEPOIS que a chamada REST já
  /// terminou (com sucesso) -- diferente do Firestore, que enfileirava a
  /// escrita e avisava antes dela completar, então não há "pendência" real
  /// pra esperar aqui, só o feedback visual de "acabou de sincronizar".
  void notificarEscrita() {
    if (!_online) {
      _setEstado(SyncEstado.offline);
      return;
    }
    _setEstado(SyncEstado.sincronizando);
    Future.delayed(const Duration(milliseconds: 400), () {
      _verificarPendencias();
    });
  }

  /// Chamado quando uma escrita falhou e foi pro [Outbox] em vez de ir
  /// direto pro servidor.
  void atualizarPendencias(int total) {
    _pendencias = total;
    _verificarPendencias();
  }

  void _verificarPendencias() {
    if (!_online) {
      _setEstado(SyncEstado.offline);
    } else if (_pendencias > 0) {
      _setEstado(SyncEstado.pendente);
    } else {
      _setEstado(SyncEstado.sincronizado);
    }
  }

  void _setEstado(SyncEstado e) {
    if (_estado == e) return;
    _estado = e;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}
