import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/api_constants.dart';
import '../../model/user.dart';
import '../api/api_client.dart';
import '../storage/secure_storage_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http_parser/http_parser.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return AuthService(apiClient, secureStorage);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Authentification synchronisée avec le backend Django (JWT).
class AuthService {
  final ApiClient _apiClient;
  final SecureStorageService _secureStorage;
  final _authStateController = StreamController<User?>.broadcast();
  User? _currentUser;

  AuthService(this._apiClient, this._secureStorage) {
    _checkInitialState();
  }

  Stream<User?> get authStateChanges => _authStateController.stream;
  User? get currentUser => _currentUser;

  Future<void> _checkInitialState() async {
    final token = await _secureStorage.getToken();
    if (token == null || token.isEmpty) {
      _authStateController.add(null);
      return;
    }
    try {
      _currentUser = await _fetchProfile();
      _authStateController.add(_currentUser);
    } catch (_) {
      await _secureStorage.deleteAll();
      _currentUser = null;
      _authStateController.add(null);
    }
  }

  Future<User> _fetchProfile() async {
    final response = await _apiClient.get(ApiConstants.profile);
    return User.fromApiJson(response.data as Map<String, dynamic>);
  }

  Future<void> _persistTokens(String access, String? refresh) async {
    await _secureStorage.saveToken(access);
    if (refresh != null && refresh.isNotEmpty) {
      await _secureStorage.saveRefreshToken(refresh);
    }
  }

  /// Connexion via POST /api/accounts/login/
  /// Accepte email ou username dans le champ email.
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    final loginId = email.trim();
    final response = await _apiClient.post(
      ApiConstants.login,
      data: {'username': loginId, 'password': password},
    );

    final data = response.data as Map<String, dynamic>;
    final access = data['access'] as String?;
    final refresh = data['refresh'] as String?;

    if (access == null) {
      throw Exception('Réponse serveur invalide (token manquant)');
    }

    await _persistTokens(access, refresh);

    if (data['user'] != null) {
      _currentUser = User.fromApiJson(data['user'] as Map<String, dynamic>);
    } else {
      _currentUser = await _fetchProfile();
    }
    _authStateController.add(_currentUser);
  }

  /// Inscription via POST /api/accounts/register/ puis connexion auto.
  Future<void> signUpWithEmailAndPassword(
    String email,
    String password, {
    String? name,
    String? phone,
  }) async {
    final trimmedEmail = email.trim();
    final username = trimmedEmail.contains('@')
        ? trimmedEmail.split('@').first
        : trimmedEmail;

    await _apiClient.post(
      ApiConstants.register,
      data: {
        'username': username,
        'email': trimmedEmail,
        'password': password,
        'password2': password,
        'name': name ?? '',
        'phone': phone ?? '',
        'role': 'reader',
      },
    );

    await signInWithEmailAndPassword(trimmedEmail, password);
  }

  Future<void> updateProfile({
    String? name,
    String? phone,
    XFile? avatarFile,
    String? companyName,
    String? siret,
    String? address,
    String? website,
    String? bio,
  }) async {
    dynamic dataToSend;
    if (avatarFile != null) {
      final formDataMap = <String, dynamic>{};
      if (name != null) formDataMap['name'] = name;
      if (phone != null) formDataMap['phone'] = phone;
      if (companyName != null) formDataMap['publisher_profile_company_name'] = companyName;
      if (siret != null) formDataMap['publisher_profile_siret'] = siret;
      if (address != null) formDataMap['publisher_profile_address'] = address;
      if (website != null) formDataMap['publisher_profile_website'] = website;
      if (bio != null) formDataMap['publisher_profile_bio'] = bio;
      
      final filename = avatarFile.name.isNotEmpty ? avatarFile.name : 'avatar.jpg';
      final mediaType = MediaType('image', 'jpeg');
      
      if (kIsWeb) {
        final bytes = await avatarFile.readAsBytes();
        formDataMap['avatar'] = MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: mediaType,
        );
      } else {
        formDataMap['avatar'] = await MultipartFile.fromFile(
          avatarFile.path,
          filename: filename,
          contentType: mediaType,
        );
      }
      dataToSend = FormData.fromMap(formDataMap);
    } else {
      final payload = <String, dynamic>{};
      if (name != null) payload['name'] = name;
      if (phone != null) payload['phone'] = phone;
      if (companyName != null || siret != null || address != null || website != null || bio != null) {
        payload['publisher_profile'] = {
          if (companyName != null) 'company_name': companyName,
          if (siret != null) 'siret': siret,
          if (address != null) 'address': address,
          if (website != null) 'website': website,
          if (bio != null) 'bio': bio,
        };
      }
      dataToSend = payload;
    }

    if (dataToSend is Map && dataToSend.isEmpty) return;

    final response = await _apiClient.patch(
      ApiConstants.profile,
      data: dataToSend,
    );
    _currentUser = User.fromApiJson(response.data as Map<String, dynamic>);
    _authStateController.add(_currentUser);
  }

  Future<void> updatePreferences(UserPreferences prefs) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(preferences: prefs);
      _authStateController.add(_currentUser);
    }
  }

  /// Étape 1 : demande un code de réinitialisation envoyé par email.
  /// Le backend répond toujours avec succès (même si l'email n'existe pas)
  /// afin de ne jamais révéler quels comptes existent.
  Future<void> recoverPassword(String email) async {
    await _apiClient.post(
      ApiConstants.passwordResetRequest,
      data: {'email': email.trim()},
    );
  }

  /// Étape 2 : vérifie le code à 6 chiffres reçu par email, sans encore
  /// modifier le mot de passe. Le code et sa validité sont vérifiés côté
  /// serveur uniquement — il n'existe plus de code "magique" côté client.
  Future<void> verifyResetCode(String email, String code) async {
    await _apiClient.post(
      ApiConstants.passwordResetVerify,
      data: {'email': email.trim(), 'code': code.trim()},
    );
  }

  /// Étape 3 : confirme la réinitialisation avec le code valide et le
  /// nouveau mot de passe choisi par l'utilisateur.
  Future<void> confirmPasswordReset(
    String email,
    String code,
    String newPassword,
  ) async {
    await _apiClient.post(
      ApiConstants.passwordResetConfirm,
      data: {
        'email': email.trim(),
        'code': code.trim(),
        'new_password': newPassword,
      },
    );
  }

  /// Conservé pour compatibilité avec l'écran de vérification existant :
  /// délègue désormais à la vérification réelle du code de réinitialisation.
  Future<void> verifyCode(String email, String code) =>
      verifyResetCode(email, code);

  /// Renvoie un nouveau code de réinitialisation (ré-émet la demande).
  Future<void> resendVerificationCode(String email) => recoverPassword(email);

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await _apiClient.post(
      'accounts/me/change-password/',
      data: {
        'old_password': currentPassword,
        'new_password': newPassword,
      },
    );
  }

  Future<void> signOut() async {
    await _secureStorage.deleteAll();
    _currentUser = null;
    _authStateController.add(null);
  }

  void dispose() {
    _authStateController.close();
  }
}
