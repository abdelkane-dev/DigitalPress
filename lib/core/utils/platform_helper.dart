import 'package:flutter/foundation.dart';

/// Utilitaire centralisé de détection de plateforme.
class PlatformHelper {
  /// Vrai si l'app tourne dans un navigateur web.
  static bool get isWeb => kIsWeb;

  /// Vrai si l'app tourne sur Android.
  static bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Vrai si l'app tourne sur iOS.
  static bool get isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Vrai si l'app tourne sur macOS (desktop).
  static bool get isMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  /// Vrai si l'app tourne sur Windows (desktop).
  static bool get isWindows => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// Vrai si l'app tourne sur Linux (desktop).
  static bool get isLinux => !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  /// Vrai si l'app tourne sur une plateforme mobile (Android ou iOS).
  static bool get isMobile => isAndroid || isIOS;

  /// Vrai si l'app tourne sur une plateforme desktop (macOS, Windows, Linux).
  static bool get isDesktop => isMacOS || isWindows || isLinux;

  /// Vrai si flutter_downloader est supporté (Android et iOS uniquement).
  static bool get supportsFlutterDownloader => isMobile;

  /// Vrai si les notifications push Firebase sont supportées.
  static bool get supportsFirebaseMessaging =>
      isAndroid || isIOS || isMacOS || isWeb;

  /// Vrai si les notifications locales sont supportées.
  static bool get supportsLocalNotifications =>
      isAndroid || isIOS || isMacOS || isLinux;

  /// Vrai si video_player est supporté.
  static bool get supportsVideoPlayer =>
      isAndroid || isIOS || isMacOS || isWeb;
}
