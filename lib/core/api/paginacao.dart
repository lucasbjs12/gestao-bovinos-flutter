import 'api_client.dart';

/// Busca todas as páginas de uma listagem paginada do backend (pageSize
/// máximo é 100 do lado do servidor) e concatena os itens -- usado pelo
/// sync, que sempre quer o estado completo, não uma página por vez.
Future<List<Map<String, dynamic>>> buscarTodasPaginas(
  ApiClient api,
  String caminhoBase,
) async {
  final itens = <Map<String, dynamic>>[];
  var page = 1;
  var totalPaginas = 1;
  do {
    final separador = caminhoBase.contains('?') ? '&' : '?';
    final resposta = await api.get('$caminhoBase${separador}page=$page&pageSize=100')
        as Map<String, dynamic>;
    final pagina = (resposta['itens'] as List).cast<Map<String, dynamic>>();
    itens.addAll(pagina);
    totalPaginas = (resposta['paginacao'] as Map<String, dynamic>)['totalPaginas'] as int;
    page++;
  } while (page <= totalPaginas);
  return itens;
}
