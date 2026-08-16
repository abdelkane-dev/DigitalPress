import 'dart:async';

/// Gestion globale de la session utilisateur.
///
/// Permet à l'[AuthInterceptor] (couche réseau, sans accès à Riverpod) de
/// signaler qu'un token est définitivement invalide, et déclencher une
/// déconnexion automatique côté UI — sans créer de dépendance circulaire.
///
/// Usage :
///   - L'intercepteur appelle [SessionManager.forceLogout()] quand le
///     refresh token est rejeté par le serveur.
///   - Le widget racine écoute [SessionManager.forceLogoutStream] et appelle
///     [AuthService.signOut()] pour vider l'état Riverpod et rediriger
///     l'utilisateur vers l'écran de connexion.
class SessionManager {
  SessionManager._();

  static final StreamController<void> _controller =
      StreamController<void>.broadcast();

  /// Stream à écouter dans le widget racine pour réagir à une déconnexion
  /// forcée (token expiré ou invalide côté serveur).
  static Stream<void> get forceLogoutStream => _controller.stream;

  /// Signale que la session est expirée et que l'utilisateur doit être
  /// déconnecté immédiatement.
  static void forceLogout() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }
}
