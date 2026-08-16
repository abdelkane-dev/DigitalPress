import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:path_provider/path_provider.dart';

import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/storage/storage_service.dart';
import 'core/services/theme_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/app_notification_service.dart' show unreadCountProvider;
import 'package:app_badge_plus/app_badge_plus.dart';
import 'core/services/permission_priming_service.dart';
import 'core/services/session_manager.dart';
import 'model/user.dart';

import 'firebase_options.dart';

Future<StorageService> _initStorage() async {
  final storage = StorageService();
  try {
    await storage.init();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('StorageService init error: $e');
    }
  }
  return storage;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ─── JOURNAL DE CRASH SUR L'APPAREIL ─────────────────────────────────
  // En release, une exception non gérée ferme l'app sans rien afficher et
  // Android peut la marquer « stopped » (icône qui ne répond plus). On
  // capture ces erreurs dans un fichier (crash.log) pour pouvoir
  // diagnostiquer la cause exacte plus tard via `adb shell run-as
  // com.digitalpress.app cat files/crash.log`.
  try {
    FlutterError.onError = (details) {
      _logCrash('FlutterError: ${details.exception}\n${details.stack}');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _logCrash('PlatformDispatcher: $error\n$stack');
      return true;
    };
  } catch (_) {}

  // Initialisation Firebase multiplateforme (générée par flutterfire)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (kDebugMode) debugPrint('Firebase init error: $e');
  }

  final storage = await _initStorage();

  runApp(
    ProviderScope(
      overrides: [
        // Inject the already-initialized StorageService singleton
        storageServiceProvider.overrideWithValue(storage),
      ],
      child: const DigitalPressApp(),
    ),
  );
}

/// Écrit une erreur fatale dans le fichier `crash.log` de l'app.
///
/// On privilégie le dossier externe de l'app
/// (`/sdcard/Android/data/com.digitalpress.app/files/`), lisible
/// directement via adb sans root :
///   adb pull /sdcard/Android/data/com.digitalpress.app/files/crash.log
/// (En fallback : documents internes de l'app.) Échec silencieux si
/// indisponible — le journal est un outil de diagnostic, jamais une
/// source de crash.
void _logCrash(String message) {
  Future<Directory?> dirFuture;
  try {
    dirFuture = getExternalStorageDirectory();
  } catch (_) {
    dirFuture = getApplicationDocumentsDirectory();
  }
  final target = dirFuture;
  target.then((d) async {
    try {
      final file = File('${(d ?? await getApplicationDocumentsDirectory()).path}/crash.log');
      await file.writeAsString(
        '${DateTime.now().toIso8601String()} — $message\n\n---\n',
        mode: FileMode.append,
      );
    } catch (_) {}
  }).catchError((_) {});
}

class DigitalPressApp extends ConsumerStatefulWidget {
  const DigitalPressApp({super.key});

  @override
  ConsumerState<DigitalPressApp> createState() => _DigitalPressAppState();
}

class _DigitalPressAppState extends ConsumerState<DigitalPressApp> {
  StreamSubscription<void>? _forceLogoutSub;

  @override
  void initState() {
    super.initState();
    // Écoute le stream de déconnexion forcée déclenché par l'AuthInterceptor
    // quand le refresh token est refusé par le serveur (ex: changement de BDD).
    _forceLogoutSub = SessionManager.forceLogoutStream.listen((_) async {
      // Une erreur async non gérée ici tuerait silencieusement l'app en
      // release (et Android la marquerait « stopped » → icône sans effet).
      try {
        await ref.read(authServiceProvider).signOut();
      } catch (_) {
        // Déconnexion déjà effectuée ou réseau indisponible : on ignore.
      }
    });
  }

  @override
  void dispose() {
    _forceLogoutSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final isDark = ref.watch(themeProvider);

    // Mettre à jour le router dans NotificationNavigator à chaque changement de route
    NotificationNavigator.setRouter(router);

    // Initialiser les notifications push dès que l'utilisateur est connecté
    ref.listen<AsyncValue<User?>>(authStateProvider, (prev, next) {
      final wasLoggedIn = prev?.valueOrNull != null;
      final isLoggedIn = next.valueOrNull != null;

      if (!wasLoggedIn && isLoggedIn) {
        // Les deux appels ci-dessous sont des tâches de fond : toute
        // exception async non gérée tuerait silencieusement l'app en
        // release (puis Android la marquerait « stopped » → l'icône ne
        // répond plus). On les isole donc chacune dans son propre filet.
        try {
          ref.read(notificationServiceProvider).init();
        } catch (_) {}
        // Demande groupée des permissions (photos/vidéos, caméra,
        // notifications) : UNE SEULE FOIS, à la toute première connexion
        // réussie sur cet appareil — jamais répétée aux connexions
        // suivantes (déconnexion/reconnexion incluses), et identique pour
        // les 3 rôles (aucun traitement différent par compte).
        try {
          ref.read(permissionPrimingServiceProvider).primeIfNeeded();
        } catch (_) {}
      }
      if (wasLoggedIn && !isLoggedIn) {
        AppBadgePlus.updateBadge(0); // déconnexion : icône propre
      }
    });

    // ─── AJOUT : badge rouge sur l'icône de l'app (écran d'accueil), comme
    // WhatsApp/YouTube — réutilise le même compteur que la cloche de
    // notifications dans l'app (unreadCountProvider), aucune logique dupliquée.
    ref.listen<int>(unreadCountProvider, (prev, next) {
      // ─── CORRECTIF : app_badge_plus ne supporte que Android/iOS/macOS.
      // Sur Windows/Linux/Web, l'appel au canal natif lève une
      // MissingPluginException non capturée (le listener Riverpod n'a pas
      // de try/catch) — badge ignoré proprement ailleurs qu'en mobile.
      final platform = Theme.of(context).platform;
      if (platform != TargetPlatform.android &&
          platform != TargetPlatform.iOS &&
          platform != TargetPlatform.macOS) {
        return;
      }
      try {
        AppBadgePlus.updateBadge(next);
      } catch (_) {
        // Échec silencieux : le badge est un confort, jamais une fatalité.
      }
    });

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
