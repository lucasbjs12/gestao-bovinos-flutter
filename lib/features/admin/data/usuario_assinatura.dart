enum StatusAssinatura { pendente, ativo, bloqueado, vencido }

class UsuarioAssinatura {
  final String uid;
  final String nome;
  final String email;
  final bool isAdmin;
  final StatusAssinatura status;
  final String? plano;
  final DateTime? vencimento;
  final DateTime criadoEm;

  const UsuarioAssinatura({
    required this.uid,
    required this.nome,
    required this.email,
    required this.isAdmin,
    required this.status,
    this.plano,
    this.vencimento,
    required this.criadoEm,
  });

  bool get acessoLiberado =>
      isAdmin || (status == StatusAssinatura.ativo && !vencido);

  bool get vencido =>
      vencimento != null && DateTime.now().isAfter(vencimento!);

  StatusAssinatura get statusEfetivo {
    if (isAdmin) return StatusAssinatura.ativo;
    if (status == StatusAssinatura.bloqueado) return StatusAssinatura.bloqueado;
    if (status == StatusAssinatura.ativo && vencido) return StatusAssinatura.vencido;
    return status;
  }

  int get diasParaVencer {
    if (vencimento == null) return 0;
    return vencimento!.difference(DateTime.now()).inDays;
  }

  /// Formato do backend próprio (`GET /admin/usuarios`): `statusAssinatura`
  /// em vez de `status`, `criadoEm`/`vencimento` como string ISO.
  factory UsuarioAssinatura.fromBackend(Map<String, dynamic> m) {
    final statusStr = m['statusAssinatura'] as String? ?? 'pendente';
    final status = StatusAssinatura.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => StatusAssinatura.pendente,
    );
    return UsuarioAssinatura(
      uid: m['id'] as String,
      nome: m['nome'] as String? ?? '',
      email: m['email'] as String? ?? '',
      isAdmin: m['isAdmin'] as bool? ?? false,
      status: status,
      plano: m['plano'] as String?,
      vencimento: m['vencimento'] != null ? DateTime.tryParse(m['vencimento'] as String) : null,
      criadoEm: DateTime.tryParse(m['criadoEm'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
