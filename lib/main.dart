import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/storage/storage_service.dart';
import 'core/services/theme_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/notification_service.dart';
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
      await ref.read(authServiceProvider).signOut();
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
        ref.read(notificationServiceProvider).init();
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
