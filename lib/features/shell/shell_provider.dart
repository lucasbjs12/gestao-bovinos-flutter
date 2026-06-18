import 'package:flutter/material.dart';

class ShellProvider extends ChangeNotifier {
  int _abaAtual = 0;

  int get abaAtual => _abaAtual;

  void setAba(int index) {
    if (_abaAtual == index) return;
    _abaAtual = index;
    notifyListeners();
  }
}
