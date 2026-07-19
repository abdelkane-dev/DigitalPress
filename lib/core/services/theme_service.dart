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
    final isDark = _storage.get('is_dark_mode', defaultValue: false) as bool;
    state = isDark;
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
