import 'package:flutter/material.dart';

import 'data/assinatura_atual.dart';
import 'data/plano.dart';
import 'data/planos_remote_repository.dart';

class AssinaturaProvider extends ChangeNotifier {
  AssinaturaProvider({PlanosRemoteRepository? repo}) : _repo = repo ?? PlanosRemoteRepository();

  final PlanosRemoteRepository _repo;

  String? _fazendaId;
  AssinaturaAtual? _assinatura;
  List<Plano> _planos = [];
  bool _isLoading = false;

  AssinaturaAtual? get assinatura => _assinatura;
  List<Plano> get planos => _planos;
  bool get isLoading => _isLoading;

  Future<void> carregar(String fazendaId) async {
    _fazendaId = fazendaId;
    await atualizar();
  }

  /// Chamado depois de cadastrar um bovino (ou de voltar da tela de
  /// planos) -- a contagem/limite só existe de verdade no backend, então
  /// isso é sempre um refetch, nunca um incremento local otimista.
  Future<void> atualizar() async {
    final fazendaId = _fazendaId;
    if (fazendaId == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      _assinatura = await _repo.obterAssinatura(fazendaId);
    } catch (_) {
      // offline ou erro passageiro -- mantém o último valor conhecido em
      // vez de derrubar a tela; o próximo carregar()/atualizar() tenta de novo.
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> carregarPlanos() async {
    try {
      _planos = await _repo.listarPlanos();
      notifyListeners();
    } catch (_) {
      // idem -- tela de planos mostra estado vazio e deixa tentar de novo.
    }
  }

  Future<String> iniciarCheckout(String planoId) {
    final fazendaId = _fazendaId;
    if (fazendaId == null) {
      throw StateError('AssinaturaProvider.carregar() precisa rodar antes do checkout');
    }
    return _repo.iniciarCheckout(fazendaId, planoId);
  }

  Future<void> cancelar() async {
    final fazendaId = _fazendaId;
    if (fazendaId == null) return;
    await _repo.cancelar(fazendaId);
    await atualizar();
  }
}
