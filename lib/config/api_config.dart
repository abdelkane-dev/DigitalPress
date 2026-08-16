import 'package:flutter/foundation.dart';
import 'app_config.dart';

class ApiConfig {
  static const String _override = String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get baseUrl {
    if (_override.isNotEmpty) {
      return _override.endsWith('/') ? _override : '$_override/';
    }
    // ─── CORRECTIF CRITIQUE ────────────────────────────────────────────
    // En version release (celle publiée sur les stores / installée sur un
    // vrai appareil), TOUTES les plateformes doivent utiliser le vrai
    // serveur VPS (AppConfig.baseUrlWeb, malgré son nom historique
    // "Web" — c'est en réalité l'URL de PRODUCTION, la seule à contenir
    // la vraie IP du VPS 192.162.71.56). Sans ce correctif, Android,
    // iOS, macOS et Windows en mode release seraient tous retombés sur
    // AppConfig.baseUrl ou baseUrlLocal, des adresses de développement
    // (IP LAN locale / localhost) inexistantes une fois l'app installée
    // sur l'appareil final — l'app aurait été non fonctionnelle sur
    // TOUTES les plateformes natives en production.
    if (kReleaseMode) {
      return AppConfig.baseUrlWeb;
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

  /// URL de base WebSocket (ws:// ou wss://), dérivée automatiquement de
  /// [baseUrl] : même hôte/port que l'API REST, juste un schéma différent.
  /// Évite de dupliquer toute la logique de sélection d'hôte par
  /// plateforme (émulateur/simulateur/vrai appareil/prod) ci-dessus.
  static String get wsBaseUrl {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null) return '';
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final portPart = uri.hasPort ? ':${uri.port}' : '';
    return '$wsScheme://${uri.host}$portPart';
  }

  /// Réécrit toute URL de média renvoyée par le backend Django pour qu'elle
  /// pointe vers l'hôte correct selon la plateforme (émulateur, simulateur,
  /// vrai appareil ou production).
  ///
  /// En dev local, le backend génère des URLs du type :
  ///   http://127.0.0.1:8000/media/covers/image.jpg
  /// Ces URLs ne fonctionnent pas sur l'émulateur Android (il faut 10.0.2.2),
  /// ni sur un vrai téléphone (il faut l'IP LAN du PC).
  ///
  /// En production, des URLs en HTTP simple, vers l'IP brute du VPS
  /// (192.162.71.56) ou vers le domaine nu (digitalpress-ml.com — intercepté
  /// par le proxy de l'hébergeur, renvoie 404) sont réécrites vers le nom de
  /// domaine officiel en HTTPS (www.digitalpress-ml.com).
  static String sanitizeUrl(String url) {
    if (url.isEmpty) return url;
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.host.isEmpty) return url;
    final actualHost = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    final isProd = uri.scheme == 'https' || kReleaseMode || kIsWeb;

    // Hôtes de développement locaux → hôte courant (émulateur/appareil).
    if (url.contains('localhost:8000') || url.contains('127.0.0.1:8000')) {
      return url
          .replaceAll('http://localhost:8000', actualHost)
          .replaceAll('http://127.0.0.1:8000', actualHost);
    }

    // En production : IP brute du VPS et domaine nu (404 via le proxy
    // hébergeur) sont TOUJOURS remplacés par le nom de domaine officiel.
    if (isProd) {
      if (url.contains('192.162.71.56') ||
          url.contains('digitalpress-ml.com') ||
          url.contains('digitalpress.ml')) {
        final path = url.replaceFirst(RegExp(r'^[a-z]+://[^/]+'), '');
        return '$actualHost$path';
      }
    }
    return url;
  }
}