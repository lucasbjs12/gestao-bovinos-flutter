import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';
import 'data/evento_sanitario_completo.dart';
import 'data/evento_sanitario_local_repository.dart';

const _pageSize = 30;

class EventosSanitariosProvider extends ChangeNotifier {
  List<EventoSanitarioCompleto> _eventos = [];
  bool _isLoading = false;
  bool _isLoadingMais = false;
  bool _temMais = false;
  int _offset = 0;
  String? _uid;
  String _termoBusca = '';
  String? _filtroTipo;
  Timer? _debounce;

  List<EventoSanitarioCompleto> get eventos => _eventos;
  bool get isLoading => _isLoading;
  bool get isLoadingMais => _isLoadingMais;
  bool get temMais => _temMais;
  String get termoBusca => _termoBusca;
  String? get filtroTipo => _filtroTipo;

  Future<void> carregar(String uid) async {
    _uid = uid;
    await _recarregar();
  }

  Future<void> recarregar() async {
    if (_uid != null) await _recarregar();
  }

  void buscar(String termo) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _termoBusca = termo;
      _recarregar();
    });
  }

  void setTipo(String? tipo) {
    if (_filtroTipo == tipo) return;
    _filtroTipo = tipo;
    _recarregar();
  }

  Future<void> carregarMais() async {
    if (_uid == null || _isLoadingMais || !_temMais) return;
    _isLoadingMais = true;
    notifyListeners();
    try {
      final db = await AppDatabase.instance.instanceFor(_uid);
      final novos = await EventoSanitarioLocalRepository(db).listar(
        tipo: _filtroTipo,
        termo: _termoBusca.isEmpty ? null : _termoBusca,
        limit: _pageSize,
        offset: _offset,
      );
      _eventos = [..._eventos, ...novos];
      _offset += novos.length;
      _temMais = novos.length == _pageSize;
    } finally {
      _isLoadingMais = false;
      notifyListeners();
    }
  }

  Future<void> _recarregar() async {
    if (_uid == null) return;
    _isLoading = true;
    _offset = 0;
    notifyListeners();
    try {
      final db = await AppDatabase.instance.instanceFor(_uid);
      _eventos = await EventoSanitarioLocalRepository(db).listar(
        tipo: _filtroTipo,
        termo: _termoBusca.isEmpty ? null : _termoBusca,
        limit: _pageSize,
        offset: 0,
      );
      _offset = _eventos.length;
      _temMais = _eventos.length == _pageSize;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
