import 'package:flutter/foundation.dart';
import 'app_config.dart';

class ApiConfig {
  static const String _override = String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get baseUrl {
    if (_override.isNotEmpty) {
      return _override.endsWith('/') ? _override : '$_override/';
    }
    if (kIsWeb) {
      return AppConfig.baseUrlWeb;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Par défaut, utilise 10.0.2.2 pour l'émulateur Android.
        // Si vous testez sur un vrai téléphone via câble USB :
        // 1. Lancez dans votre terminal : `adb reverse tcp:8000 tcp:8000`
        // 2. Vous pouvez alors utiliser 'http://127.0.0.1:8000/api/' (baseUrlLocal)
        // Sinon, passez votre IP locale via : --dart-define=API_BASE_URL=http://<IP_PC>:8000/api/
        return AppConfig.baseUrl;
      default:
        return AppConfig.baseUrlLocal;
    }
  }

  /// Réécrit toute URL de média renvoyée par le backend Django pour qu'elle
  /// pointe vers l'hôte correct selon la plateforme (émulateur, simulateur,
  /// vrai appareil ou production).
  ///
  /// En dev local, le backend génère des URLs du type :
  ///   http://127.0.0.1:8000/media/covers/image.jpg
  /// Ces URLs ne fonctionnent pas sur l'émulateur Android (il faut 10.0.2.2),
  /// ni sur un vrai téléphone (il faut l'IP LAN du PC).
  /// Cette méthode remplace dynamiquement l'hôte par la valeur de [baseUrl].
  static String sanitizeUrl(String url) {
    if (url.isEmpty) return url;
    if (url.contains('localhost:8000') || url.contains('127.0.0.1:8000')) {
      final uri = Uri.tryParse(baseUrl);
      if (uri == null) return url;
      final actualHost = '${uri.scheme}://${uri.host}:${uri.port}';
      return url
          .replaceAll('http://localhost:8000', actualHost)
          .replaceAll('http://127.0.0.1:8000', actualHost);
    }
    return url;
  }
}