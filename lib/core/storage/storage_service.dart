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
  Future<void> init() async {
    await Hive.initFlutter();

    // Récupère ou génère une clé de chiffrement sécurisée.
    final encryptionKey = await _getOrCreateEncryptionKey();

    // Ouvre la boîte avec un algorithme de chiffrement AES.
    _settingsBox = await Hive.openBox(
      _settingsBoxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
  }

  /// Génère une clé de chiffrement robuste et la stocke dans Secure Storage.
  Future<List<int>> _getOrCreateEncryptionKey() async {
    const secureStorage = FlutterSecureStorage();
    final containsEncryptionKey = await secureStorage.containsKey(
      key: _encryptionKeyName,
    );

    if (!containsEncryptionKey) {
      // Génère une clé aléatoire sécurisée.
      final key = Hive.generateSecureKey();
      await secureStorage.write(
        key: _encryptionKeyName,
        value: base64UrlEncode(key),
      );
    }

    // Récupère la clé existante.
    final encodedKey = await secureStorage.read(key: _encryptionKeyName);
    return base64Url.decode(encodedKey!);
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
