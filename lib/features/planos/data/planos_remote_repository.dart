import '../../../core/api/api_client.dart';
import 'assinatura_atual.dart';
import 'plano.dart';

class PlanosRemoteRepository {
  PlanosRemoteRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<Plano>> listarPlanos() async {
    final dados = await _api.get('/planos') as List;
    return dados.map((e) => Plano.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<AssinaturaAtual> obterAssinatura(String fazendaId) async {
    final dados = await _api.get('/fazendas/$fazendaId/assinatura') as Map<String, dynamic>;
    return AssinaturaAtual.fromMap(dados);
  }

  /// Retorna a URL de checkout do Mercado Pago -- a tela abre num
  /// navegador/webview externo, o app nunca vê dado de pagamento nenhum.
  Future<String> iniciarCheckout(String fazendaId, String planoId) async {
    final dados = await _api.post(
      '/fazendas/$fazendaId/assinatura/checkout',
      corpo: {'planoId': planoId},
    ) as Map<String, dynamic>;
    return dados['checkoutUrl'] as String;
  }

  Future<void> cancelar(String fazendaId) =>
      _api.post('/fazendas/$fazendaId/assinatura/cancelar');
}
