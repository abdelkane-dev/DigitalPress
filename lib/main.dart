import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/storage/storage_service.dart';
import 'core/services/theme_service.dart';

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

  // Initialisation Firebase (sécurisée — désactivée si google-services.json absent)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    if (kDebugMode) debugPrint('Firebase init skipped: $e');
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

class DigitalPressApp extends ConsumerWidget {
  const DigitalPressApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final isDark = ref.watch(themeProvider);

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
          child: child!,
        );
      },
    );
  }
}
