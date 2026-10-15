import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fournisseur pour le service de base de données locale [Hive].
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

/// Service gérant la base de données locale (Hive) avec chiffrement AES.
/// Utilisé pour stocker les préférences et les données en cache.
class StorageService {
  static const String _encryptionKeyName = 'hive_encryption_key';
  static const String _settingsBoxName = 'settings';

  late Box _settingsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    try {
      final encryptionKey = await _getOrCreateEncryptionKey();
      _settingsBox = await Hive.openBox(
        _settingsBoxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
    } catch (e) {
      // Encryption may fail on web (IndexedDB doesn't always support AES).
      // Try opening without encryption as fallback.
      try {
        _settingsBox = await Hive.openBox('${_settingsBoxName}_plain');
        return;
      } catch (_) {}
      try {
        await Hive.deleteBoxFromDisk(_settingsBoxName);
      } catch (_) {}
      try {
        final newKey = Hive.generateSecureKey();
        const secureStorage = FlutterSecureStorage();
        await secureStorage.write(
          key: _encryptionKeyName,
          value: base64UrlEncode(newKey),
        );
        _settingsBox = await Hive.openBox(
          _settingsBoxName,
          encryptionCipher: HiveAesCipher(newKey),
        );
      } catch (_) {
        try {
          _settingsBox = await Hive.openBox(_settingsBoxName);
        } catch (_) {
          try {
            _settingsBox = Hive.box(_settingsBoxName);
          } catch (_) {
            // Last resort: in-memory box so _settingsBox is never uninitialized.
            _settingsBox = await Hive.openBox('settings_fallback_$runtimeType');
          }
        }
      }
    }
  }

  Future<List<int>> _getOrCreateEncryptionKey() async {
    const secureStorage = FlutterSecureStorage();
    var encodedKey = await secureStorage.read(key: _encryptionKeyName);

    if (encodedKey == null || encodedKey.isEmpty) {
      final key = Hive.generateSecureKey();
      encodedKey = base64UrlEncode(key);
      await secureStorage.write(
        key: _encryptionKeyName,
        value: encodedKey,
      );
    }

    try {
      return base64Url.decode(encodedKey);
    } catch (_) {
      final key = Hive.generateSecureKey();
      final newEncoded = base64UrlEncode(key);
      await secureStorage.write(
        key: _encryptionKeyName,
        value: newEncoded,
      );
      return key;
    }
  }

  /// Enregistre une valeur dans la boîte Hive.
  Future<void> set(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  /// Récupère une valeur. Si elle n'existe pas, retourne [defaultValue].
  dynamic get(String key, {dynamic defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue);
  }

  /// Supprime une entrée spécifique.
  Future<void> delete(String key) async {
    await _settingsBox.delete(key);
  }

  /// Vide tout le contenu de la boîte (réinitialisation).
  Future<void> clearAll() async {
    await _settingsBox.clear();
  }

  // ─── CACHE AVEC TTL ─────────────────────────────────────────────────────
  // Stocke des données avec un timestamp pour savoir quand elles sont
  // expirées. Permet de servir le cache immédiatement (instant UI)
  // tout en refreshant en arrière-plan quand les données sont stale.

  /// Enregistre des données avec un TTL en secondes.
  /// [ttl] = durée de vie en secondes. 0 = pas d'expiration.
  Future<void> setWithTTL(String key, dynamic value, {int ttl = 300}) async {
    final entry = {
      'data': value,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'ttl': ttl,
    };
    await _settingsBox.put('cache_$key', entry);
  }

  /// Récupère des données en cache. Retourne null si expirées ou absentes.
  dynamic getFromCache(String key) {
    final entry = _settingsBox.get('cache_$key');
    if (entry == null || entry is! Map) return null;

    final timestamp = entry['timestamp'] as int? ?? 0;
    final ttl = entry['ttl'] as int? ?? 300;
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;

    // TTL = 0 signifie pas d'expiration (données quasi-permanentes
    // comme les catégories)
    if (ttl > 0 && age > ttl * 1000) return null;

    return entry['data'];
  }

  /// Vérifie si des données en cache sont stale (expirées ou presque).
  /// [gracePeriod] : secondes avant expiration où on considère que c'est
  /// "presque stale" et qu'on doit lancer un refresh en arrière-plan.
  bool isCacheStale(String key, {int gracePeriod = 60}) {
    final entry = _settingsBox.get('cache_$key');
    if (entry == null || entry is! Map) return true;

    final timestamp = entry['timestamp'] as int? ?? 0;
    final ttl = entry['ttl'] as int? ?? 300;
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;

    if (ttl <= 0) return false; // Pas d'expiration
    return age > (ttl - gracePeriod) * 1000;
  }
}
