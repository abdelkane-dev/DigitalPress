/// Classe de base pour représenter les erreurs (ou "failures") dans l'application.
/// On utilise des failures au lieu de simples exceptions pour une meilleure gestion d'UI.
abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

/// Représente une erreur provenant du serveur backend.
class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Erreur serveur']);
}

/// Représente une impossibilité de joindre le réseau (timeout, pas de Wi-Fi, etc.).
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Pas de connexion internet']);
}

/// Représente une erreur liée à l'authentification (login invalide, session expirée).
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Erreur d\'authentification']);
}

/// Représente une erreur d'accès ou d'écriture dans la base de données locale (Hive).
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Erreur de cache']);
}
