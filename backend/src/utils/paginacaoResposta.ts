export function respostaPaginada<T>(itens: T[], total: number, page: number, pageSize: number) {
  return {
    itens,
    paginacao: { page, pageSize, total, totalPaginas: Math.ceil(total / pageSize) },
  };
}
