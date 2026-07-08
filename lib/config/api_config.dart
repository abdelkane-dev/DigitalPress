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
}