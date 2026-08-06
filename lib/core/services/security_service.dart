import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/platform_helper.dart';

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService();
});

class SecurityService {
  static const platform = MethodChannel('com.example.digitalpress/security');

  /// Active ou désactive la protection contre les captures d'écran (DRM).
  ///
  /// Comportement par plateforme :
  /// - **Android** : utilise FLAG_SECURE (interdit captures d'écran + écran opaque
  ///   dans les tâches récentes).
  /// - **iOS** : pas de FLAG_SECURE natif, mais un MethodChannel pourrait être
  ///   ajouté pour utiliser `UITextField.isSecureTextEntry` (technique avancée).
  /// - **macOS / Windows / Linux / Web** : aucune protection native disponible.
  ///   Le watermark d'identité reste la principale dissuasion sur ces plateformes.
  Future<void> setSecureMode(bool enable) async {
    if (kIsWeb) return;
    if (!PlatformHelper.isAndroid) return;
    try {
      await platform.invokeMethod<void>('setSecureMode', {'enable': enable});
    } catch (e) {
      // En cas d'erreur (ex: ancienne version d'Android), on ignore silencieusement.
    }
  }

  /// Initialise les protections globales au démarrage de l'application.
  void init() {
    // Pas de protection globale : uniquement active sur les écrans de lecture.
  }
}
