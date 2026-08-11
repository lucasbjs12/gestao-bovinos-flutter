/// Mapa entre o enum sem acento do backend (`TipoEventoSanitario` no
/// Prisma) e o texto acentuado usado no app (dropdowns, filtros etc. já
/// existentes antes da migração pro backend próprio).
const Map<String, String> tipoEventoBackendParaLocal = {
  'Vacinacao': 'Vacinação',
  'Vermifugacao': 'Vermifugação',
  'Medicacao': 'Medicação',
  'Castracao': 'Castração',
  'Banho': 'Banho',
  'Outros': 'Outros',
};

const Map<String, String> tipoEventoLocalParaBackend = {
  'Vacinação': 'Vacinacao',
  'Vermifugação': 'Vermifugacao',
  'Medicação': 'Medicacao',
  'Castração': 'Castracao',
  'Banho': 'Banho',
  'Outros': 'Outros',
};
