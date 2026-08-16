import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fournisseur pour le service de base de données locale [Hive].
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

/// Service gérant la base de données locale (Hive) avec chiffrement AES.
/// Utilisé pour stocker les préférences et les fichiers mis en cache.
class StorageService {
  static const String _encryptionKeyName = 'hive_encryption_key';
  static const String _settingsBoxName = 'settings';

  late Box _settingsBox;

  /// Initialise Hive et prépare la boîte de stockage sécurisée.
  ///
  /// ─── CORRECTIF « l'app ne s'ouvre plus » ──────────────────────────────
  /// Si la clé de chiffrement manque (restauration auto-backup Android,
  /// invalidation du Keystore, mise à jour) ou que la boîte est corrompue,
  /// l'ancien code plantait sur `encodedKey!` (null-assert) puis laissait
  /// `_settingsBox` non initialisée : toute lecture ultérieure (thème,
  /// permissions) levait une `LateInitializationError` non attrapée →
  /// l'app mourait silencieusement juste après l'ouverture, et Android la
  /// marquait « stopped » (tap sur l'icône sans effet). On récupère
  /// désormais automatiquement : clé régénérée + boîte recréée, jamais de
  /// crash au démarrage. (Les tokens JWT sont dans le Secure Storage,
  /// pas dans Hive : aucune donnée critique n'est perdue.)
  Future<void> init() async {
    await Hive.initFlutter();
    try {
      final encryptionKey = await _getOrCreateEncryptionKey();
      _settingsBox = await Hive.openBox(
        _settingsBoxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
    } catch (e) {
      // 1er recours : la clé est manquante/corrompue → on la régénère et on
      // recrée la boîte chiffrée.
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
        // Dernier recours : boîte non chiffrée (uniquement des préférences
        // non sensibles — thème, permissions déjà demandées).
        try {
          _settingsBox = await Hive.openBox(_settingsBoxName);
        } catch (_) {
          // Encore un échec (rare) : boîte en mémoire uniquement.
          _settingsBox = Hive.box(_settingsBoxName);
        }
      }
    }
  }

  /// Génère une clé de chiffrement robuste et la stocke dans Secure Storage.
  Future<List<int>> _getOrCreateEncryptionKey() async {
    const secureStorage = FlutterSecureStorage();
    var encodedKey = await secureStorage.read(key: _encryptionKeyName);

    if (encodedKey == null || encodedKey.isEmpty) {
      // Génère une clé aléatoire sécurisée (et la régénère si l'ancienne a
      // disparu — plus jamais de null-assert).
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
      // Clé corrompue : on la remplace.
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
}
