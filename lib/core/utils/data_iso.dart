/// Converte uma data no formato brasileiro ("dd/MM/yyyy", usado em toda a UI
/// e no armazenamento local) para o formato ISO ("yyyy-MM-dd") que o
/// backend exige (`z.coerce.date()` no Zod -- `new Date("15/07/2026")` do
/// lado do Node dá `Invalid Date`, e o Zod rejeita com 422).
///
/// Bug real encontrado em produção: o app mandava a data brasileira direto
/// pro backend, que rejeitava toda escrita com data (evento sanitário,
/// nascimento, baixa, movimentação) com 422 -- silenciosamente, porque a
/// chamada é fire-and-forget. O registro ficava só local até a próxima
/// sincronização apagar ele por "não existir no servidor".
String? dataBrParaIso(String? dataBr) {
  if (dataBr == null || dataBr.isEmpty) return null;
  final partes = dataBr.split('/');
  if (partes.length != 3) return dataBr; // não é dd/MM/yyyy, manda como está
  final dia = partes[0].padLeft(2, '0');
  final mes = partes[1].padLeft(2, '0');
  final ano = partes[2];
  return '$ano-$mes-$dia';
}
