import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService();
});

class SecurityService {
  static const platform = MethodChannel('com.example.digitalpress/security');

  /// Active ou désactive la protection contre les captures d'écran (DRM).
  /// Sur Android, utilise FLAG_SECURE pour rendre l'écran opaque dans le
  /// récent, les notifications et interdire les captures d'écran système.
  Future<void> setSecureMode(bool enable) async {
    if (!Platform.isAndroid) return;
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
