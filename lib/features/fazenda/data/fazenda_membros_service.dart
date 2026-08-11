import '../../../core/api/api_client.dart';
import 'convite.dart';
import 'membro.dart';

/// Gestão de membros e convites de uma fazenda, via backend próprio.
class FazendaMembrosService {
  static final _api = ApiClient();

  static const conviteValidadeHoras = 48;

  static Future<List<Membro>> listarMembros(String fazendaId) async {
    final dados = await _api.get('/fazendas/$fazendaId/membros') as List;
    final membros = dados
        .cast<Map<String, dynamic>>()
        .map(Membro.fromBackend)
        .toList();
    membros.sort((a, b) {
      if (a.ehDono != b.ehDono) return a.ehDono ? -1 : 1;
      return (a.nome ?? '').compareTo(b.nome ?? '');
    });
    return membros;
  }

  static Future<void> removerMembro(String fazendaId, String membroUid) =>
      _api.delete('/fazendas/$fazendaId/membros/$membroUid');

  /// Gera um convite de convidado (o backend cria o código) e devolve o código.
  static Future<String> gerarConvite(String fazendaId) async {
    final dados =
        await _api.post('/fazendas/$fazendaId/convites') as Map<String, dynamic>;
    return dados['codigo'] as String;
  }

  /// Lê um convite pelo código (usado pela tela do convidado).
  static Future<Convite?> buscarConvite(String codigo) async {
    try {
      final dados = await _api.get('/convites/${codigo.trim().toUpperCase()}')
          as Map<String, dynamic>;
      return Convite.fromBackend(dados);
    } catch (_) {
      return null;
    }
  }

  /// O convidado entra na fazenda. Retorna o fazendaId ingressado e o nome
  /// da fazenda (para exibição).
  static Future<({String fazendaId, String? nome})> aceitarConvite(
      String codigo) async {
    final normalizado = codigo.trim().toUpperCase();
    final dados = await _api.post('/convites/$normalizado/aceitar')
        as Map<String, dynamic>;
    final fazenda = dados['fazenda'] as Map<String, dynamic>;
    return (fazendaId: fazenda['id'] as String, nome: fazenda['nome'] as String?);
  }
}
