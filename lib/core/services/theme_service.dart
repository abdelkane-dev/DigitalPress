import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:digital_press/core/storage/storage_service.dart';

/// Provider global pour le thème (dark/light).
/// Remplace l'ancien ThemeProvider (ChangeNotifier) + provider package.
final themeProvider = StateNotifierProvider<ThemeNotifier, bool>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ThemeNotifier(storage);
});

class ThemeNotifier extends StateNotifier<bool> {
  final StorageService _storage;

  ThemeNotifier(this._storage) : super(false) {
    _load();
  }

  Future<void> _load() async {
    // ─── CORRECTIF « l'app ne s'ouvre plus » ────────────────────────────
    // Si la boîte Hive n'a pas pu être ouverte (clé de chiffrement perdue),
    // _storage.get() levait une LateInitializationError NON attrapée depuis
    // un callback async → l'app mourait silencieusement au démarrage en
    // release et Android la marquait « stopped » (tap sur l'icône sans
    // effet). On ne laisse plus jamais une erreur async non gérée ici.
    try {
      final isDark = _storage.get('is_dark_mode', defaultValue: false) as bool;
      state = isDark;
    } catch (_) {
      // Valeur par défaut : thème clair. Le démarrage ne doit jamais
      // dépendre de la réussite d'une lecture de préférence.
      state = false;
    }
  }

  Future<void> toggle() async {
    state = !state;
    await _storage.set('is_dark_mode', state);
  }

  Future<void> setDark(bool value) async {
    state = value;
    await _storage.set('is_dark_mode', value);
  }
}
