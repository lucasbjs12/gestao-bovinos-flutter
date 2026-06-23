import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';
import '../invernadas/data/invernada_local_repository.dart';
import 'data/bovino.dart';
import 'data/bovino_local_repository.dart';

const _pageSize = 30;

class BovinosProvider extends ChangeNotifier {
  List<Bovino> _bovinos = [];
  bool _isLoading = false;
  bool _isLoadingMais = false;
  bool _temMais = false;
  int _offset = 0;
  String _termoBusca = '';
  String? _filtroCategoria;
  BovinoOrdem _ordem = BovinoOrdem.brinco;
  String? _uid;
  Timer? _debounce;

  List<Bovino> get bovinos => _bovinos;
  bool get isLoading => _isLoading;
  bool get isLoadingMais => _isLoadingMais;
  bool get temMais => _temMais;
  String get termoBusca => _termoBusca;
  String? get filtroCategoria => _filtroCategoria;
  BovinoOrdem get ordem => _ordem;

  void setOrdem(BovinoOrdem o) {
    if (_ordem == o) return;
    _ordem = o;
    _recarregar();
  }

  Future<void> carregar(String uid) async {
    _uid = uid;
    await _recarregar();
  }

  Future<void> recarregar() => _recarregar();

  void buscar(String termo) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _termoBusca = termo;
      _recarregar();
    });
  }

  void setCategoria(String? cat) {
    if (_filtroCategoria == cat) return;
    _filtroCategoria = cat;
    _recarregar();
  }

  Future<void> carregarMais() async {
    if (_uid == null || _isLoadingMais || !_temMais) return;
    _isLoadingMais = true;
    notifyListeners();
    try {
      final db = await AppDatabase.instance.instanceFor(_uid);
      final repo = BovinoLocalRepository(db);
      final novos = await repo.listarAtivos(
        termo: _termoBusca.isEmpty ? null : _termoBusca,
        categoria: _filtroCategoria,
        limit: _pageSize,
        offset: _offset,
        ordem: _ordem,
      );
      _bovinos = [..._bovinos, ...novos];
      _offset += novos.length;
      _temMais = novos.length == _pageSize;
    } finally {
      _isLoadingMais = false;
      notifyListeners();
    }
  }

  /// Move os bovinos para uma nova invernada (null = sem invernada).
  /// Retorna os bovinos atualizados para sincronização remota.
  Future<List<Bovino>> moverParaInvernada(
      List<int> ids, int? novaInvernadaId) async {
    if (_uid == null) return [];
    final db = await AppDatabase.instance.instanceFor(_uid);
    return InvernadaLocalRepository(db).moverBovinos(
      bovinoIds: ids,
      novaInvernadaId: novaInvernadaId,
    );
  }

  Future<void> darBaixa(
    int id, {
    required String motivo,
    required DateTime data,
  }) async {
    if (_uid == null) return;
    final db = await AppDatabase.instance.instanceFor(_uid);
    await BovinoLocalRepository(db).darBaixaBovino(
      id: id,
      motivo: motivo,
      dataBaixa: '${data.day.toString().padLeft(2, '0')}/'
          '${data.month.toString().padLeft(2, '0')}/'
          '${data.year}',
      dataBaixaMillis: data.millisecondsSinceEpoch,
    );
  }

  Future<void> _recarregar() async {
    if (_uid == null) return;
    _isLoading = true;
    _offset = 0;
    notifyListeners();
    try {
      final db = await AppDatabase.instance.instanceFor(_uid);
      final repo = BovinoLocalRepository(db);
      _bovinos = await repo.listarAtivos(
        termo: _termoBusca.isEmpty ? null : _termoBusca,
        categoria: _filtroCategoria,
        limit: _pageSize,
        offset: 0,
        ordem: _ordem,
      );
      _offset = _bovinos.length;
      _temMais = _bovinos.length == _pageSize;
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
