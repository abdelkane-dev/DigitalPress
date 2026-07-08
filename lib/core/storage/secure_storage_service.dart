import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fournisseur pour l'accès au stockage sécurisé (Keychain/Keystore).
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Service gérant la persistance des données sensibles (tokens, clés de chiffrement).
class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  static const _tokenKey = 'jwt_token';
  static const _refreshTokenKey = 'refresh_token';

  /// Sauvegarde le token JWT de session.
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Récupère le token JWT de session.
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Sauvegarde le refresh token pour le renouvellement de session.
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  /// Récupère le refresh token.
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  /// Supprime toutes les données stockées (déconnexion).
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }
}
