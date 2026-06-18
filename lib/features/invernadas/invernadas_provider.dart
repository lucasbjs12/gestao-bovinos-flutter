import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';
import 'data/invernada.dart';
import 'data/invernada_local_repository.dart';

class InvernadasProvider extends ChangeNotifier {
  List<Invernada> _invernadas = [];
  bool _isLoading = false;
  String? _uid;

  List<Invernada> get invernadas => _invernadas;
  bool get isLoading => _isLoading;

  Future<void> carregar(String uid) async {
    _uid = uid;
    _isLoading = true;
    notifyListeners();
    try {
      final db = await AppDatabase.instance.instanceFor(uid);
      _invernadas = await InvernadaLocalRepository(db).listar();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> recarregar() async {
    if (_uid != null) await carregar(_uid!);
  }
}
