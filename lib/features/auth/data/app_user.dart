/// Substitui o `User` do Firebase Auth nas telas -- só os campos que eram
/// realmente usados fora do AuthProvider (`.uid`, `.email`, `.displayName`).
class AppUser {
  final String uid;
  final String email;
  final String displayName;

  const AppUser({required this.uid, required this.email, required this.displayName});
}
