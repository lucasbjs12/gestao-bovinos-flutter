/// Usuario tal como o backend proprio devolve (sem senhaHash, que a API
/// nunca expoe). Segue a convencao do projeto de fromMap manual (sem
/// codegen).
class UsuarioBackend {
  final String id;
  final String nome;
  final String email;
  final bool isAdmin;
  final bool emailVerificado;
  final String statusAssinatura;

  const UsuarioBackend({
    required this.id,
    required this.nome,
    required this.email,
    required this.isAdmin,
    required this.emailVerificado,
    required this.statusAssinatura,
  });

  factory UsuarioBackend.fromMap(Map<String, dynamic> map) {
    return UsuarioBackend(
      id: map['id'] as String,
      nome: map['nome'] as String,
      email: map['email'] as String,
      isAdmin: map['isAdmin'] as bool? ?? false,
      emailVerificado: map['emailVerificado'] as bool? ?? false,
      statusAssinatura: map['statusAssinatura'] as String? ?? 'pendente',
    );
  }
}

class FazendaBackend {
  final String id;
  final String donoId;
  final String nome;

  const FazendaBackend({required this.id, required this.donoId, required this.nome});

  factory FazendaBackend.fromMap(Map<String, dynamic> map) {
    return FazendaBackend(
      id: map['id'] as String,
      donoId: map['donoId'] as String,
      nome: map['nome'] as String,
    );
  }
}

/// Resultado de registro/login/refresh: usuario + par de tokens.
class SessaoBackend {
  final UsuarioBackend usuario;
  final String accessToken;
  final String refreshToken;
  final FazendaBackend? fazenda;

  const SessaoBackend({
    required this.usuario,
    required this.accessToken,
    required this.refreshToken,
    this.fazenda,
  });

  factory SessaoBackend.fromMap(Map<String, dynamic> map) {
    return SessaoBackend(
      usuario: UsuarioBackend.fromMap(map['usuario'] as Map<String, dynamic>),
      accessToken: map['accessToken'] as String,
      refreshToken: map['refreshToken'] as String,
      fazenda: map['fazenda'] != null
          ? FazendaBackend.fromMap(map['fazenda'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Resposta de `GET /auth/me`.
class PerfilBackend {
  final UsuarioBackend usuario;
  final FazendaBackend? fazendaPropria;

  const PerfilBackend({required this.usuario, this.fazendaPropria});

  factory PerfilBackend.fromMap(Map<String, dynamic> map) {
    return PerfilBackend(
      usuario: UsuarioBackend.fromMap(map['usuario'] as Map<String, dynamic>),
      fazendaPropria: map['fazendaPropria'] != null
          ? FazendaBackend.fromMap(map['fazendaPropria'] as Map<String, dynamic>)
          : null,
    );
  }
}
