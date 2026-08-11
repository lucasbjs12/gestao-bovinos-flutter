import type { Paginacao } from "./invernadas";

/// O backend pagina em pageSize máximo 100. As telas do painel hoje
/// carregam a lista inteira de uma vez e paginam/filtram no cliente --
/// esse helper busca todas as páginas e concatena, pra manter esse
/// comportamento sem reescrever a lógica de cada tela.
export async function buscarTodasPaginas<T>(
  buscarPagina: (page: number) => Promise<{ itens: T[]; paginacao: Paginacao }>
): Promise<T[]> {
  const primeira = await buscarPagina(1);
  const itens = [...primeira.itens];
  for (let page = 2; page <= primeira.paginacao.totalPaginas; page++) {
    const resultado = await buscarPagina(page);
    itens.push(...resultado.itens);
  }
  return itens;
}
