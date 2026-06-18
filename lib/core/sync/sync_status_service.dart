import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

enum SyncEstado { sincronizado, sincronizando, offline }

class SyncStatusService extends ChangeNotifier {
  SyncEstado _estado = SyncEstado.sincronizado;
  SyncEstado get estado => _estado;

  bool _online = true;
  bool _iniciado = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

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
      }
    });
  }

  void notificarEscrita() {
    if (!_online) {
      _setEstado(SyncEstado.offline);
      return;
    }
    _setEstado(SyncEstado.sincronizando);
    _verificarPendencias();
  }

  void _verificarPendencias() {
    if (!_online) {
      _setEstado(SyncEstado.offline);
      return;
    }
    FirebaseFirestore.instance.waitForPendingWrites().then((_) {
      _setEstado(SyncEstado.sincronizado);
    }).catchError((_) {
      // Conexão caiu no meio — o listener de rede vai ajustar o estado.
    });
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
