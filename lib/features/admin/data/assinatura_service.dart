import '../../../core/api/api_client.dart';
import 'usuario_assinatura.dart';

class AssinaturaService {
  static final _api = ApiClient();

  static Future<List<UsuarioAssinatura>> listarTodos() async {
    final dados = await _api.get('/admin/usuarios?pageSize=100') as Map<String, dynamic>;
    final itens = (dados['itens'] as List).cast<Map<String, dynamic>>();
    return itens.map(UsuarioAssinatura.fromBackend).toList();
  }

  static Future<void> ativar({
    required String uid,
    required String plano,
    required DateTime vencimento,
  }) =>
      _api.patch('/admin/usuarios/$uid/assinatura', corpo: {
        'statusAssinatura': 'ativo',
        'plano': plano,
        'vencimento': vencimento.toIso8601String().substring(0, 10),
      });

  static Future<void> bloquear(String uid) => _api.patch(
        '/admin/usuarios/$uid/assinatura',
        corpo: {'statusAssinatura': 'bloqueado'},
      );

  // Sem endpoint no backend para promover/remover admin ainda (só via
  // acesso direto ao banco) -- ver painel_admin_screen.dart, botão removido.
}
