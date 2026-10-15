import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/api_constants.dart';
import '../../model/user.dart';
import '../api/api_client.dart';
import '../storage/secure_storage_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart' show PlatformException;
import 'package:http_parser/http_parser.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../config/app_config.dart';
import '../storage/storage_service.dart';



/// Levée quand l'utilisateur ferme le sélecteur de compte Google sans en
/// choisir un — l'appelant doit la traiter comme une annulation silencieuse,
/// pas comme une erreur à afficher.
class SocialLoginCancelledException implements Exception {
  const SocialLoginCancelledException();
}

/// Levée quand le backend répond que le compte (créé via Google/Facebook)
/// doit d'abord activer son email avec le code OTP reçu (15 min) avant de
/// pouvoir se connecter — l'app doit rediriger vers l'écran de saisie du
/// code (voir /auth/verification?mode=activate).
class EmailVerificationRequiredException implements Exception {
  final String email;
  const EmailVerificationRequiredException(this.email);
}

final authServiceProvider = Provider<AuthService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);
  final storage = ref.watch(storageServiceProvider);
  return AuthService(apiClient, secureStorage, storage);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Authentification synchronisée avec le backend Django (JWT).
class AuthService {
  final ApiClient _apiClient;
  final SecureStorageService _secureStorage;
  final StorageService _storageService;
  final _authStateController = StreamController<User?>.broadcast();
  User? _currentUser;

  AuthService(this._apiClient, this._secureStorage, this._storageService) {
    _checkInitialState();
  }

  Stream<User?> get authStateChanges => _authStateController.stream;
  User? get currentUser => _currentUser;

  void _setUserAndNotify(User? user) {
    _currentUser = user;
    _authStateController.add(user);
    if (user != null) {
      _storageService.set('cached_user_profile', user.toJson());
    } else {
      _storageService.delete('cached_user_profile');
    }
  }

  Future<void> _checkInitialState() async {
    try {
      final token = await _secureStorage.getToken();
      if (token == null || token.isEmpty) {
        _setUserAndNotify(null);
        return;
      }

      // 1. Restauration instantanée depuis le cache local (élimine les temps de chargement/blancs au lancement)
      try {
        final cachedData = _storageService.get('cached_user_profile');
        if (cachedData != null && cachedData is Map) {
          _currentUser = User.fromJson(Map<String, dynamic>.from(cachedData));
          _authStateController.add(_currentUser);
        }
      } catch (_) {}

      // 2. Synchronisation en arrière-plan avec le backend
      try {
        final user = await _fetchProfile();
        _setUserAndNotify(user);
      } on DioException catch (dioErr) {
        // Déconnexion uniquement si le refresh token est réellement rejeté (401 définitif)
        if (dioErr.response?.statusCode == 401) {
          try { await _secureStorage.deleteAll(); } catch (_) {}
          _setUserAndNotify(null);
        } else {
          // Erreur réseau/hors-ligne : on préserve la session utilisateur locale
          if (_currentUser != null) {
            _authStateController.add(_currentUser);
          }
        }
      } catch (_) {
        // En cas d'erreur de connexion, on conserve l'utilisateur en mémoire
        if (_currentUser != null) {
          _authStateController.add(_currentUser);
        }
      }
    } catch (_) {
      // Échec critique du keystore sécurisé
      _setUserAndNotify(null);
    }
  }

  Future<User> _fetchProfile() async {
    final response = await _apiClient.get(ApiConstants.profile);
    return User.fromApiJson(response.data );
  }

  /// Recharge le profil depuis le backend et republie l'état (ex: après
  /// validation d'une vérification éditeur ou un changement de palier
  /// automatique, pour que le router relise immédiatement
  /// `isPublisherActive` / `verificationStatus` sans devoir se reconnecter).
  Future<void> refreshProfile() async {
    try {
      final user = await _fetchProfile();
      _setUserAndNotify(user);
    } catch (_) {
      // Si le profil ne peut pas être rechargé (ex: token expiré), on
      // laisse l'intercepteur/le router gérer la reconnexion normalement.
    }
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

    final data = response.data ;
    final access = data['access'] as String?;
    final refresh = data['refresh'] as String?;

    if (access == null) {
      throw Exception('Réponse serveur invalide (token manquant)');
    }

    await _persistTokens(access, refresh);

    if (data['user'] != null) {
      _setUserAndNotify(User.fromApiJson(data['user'] ));
    } else {
      final user = await _fetchProfile();
      _setUserAndNotify(user);
    }
  }

  /// Inscription via POST /api/accounts/register/.
  ///
  /// [role] : 'reader' (lecteur) ou 'publisher' (éditeur — l'éditeur
  /// s'inscrit lui-même puis se connecte et poursuit son processus initial,
  /// voir apps.accounts.serializers.RegisterSerializer).
  ///
  /// Contrairement à avant, l'inscription ne connecte PAS automatiquement :
  /// tout utilisateur (lecteur comme éditeur) est redirigé vers la page de
  /// connexion pour se connecter et continuer selon son type de compte —
  /// c'est le comportement demandé explicitement.
  Future<void> signUpWithEmailAndPassword(
    String email,
    String password, {
    String? name,
    String? phone,
    String role = 'reader',
    String? companyName,
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
        'role': role,
        if (companyName != null && companyName.isNotEmpty)
          'company_name': companyName,
      },
    );
  }

  /// Connexion ou inscription via un fournisseur social (Google, Facebook).
  Future<void> signInWithSocial(
    String provider, {
    required String email,
    String? name,
    String? providerId,
  }) async {
    final response = await _apiClient.post(
      'accounts/social-login/',
      data: {
        'provider': provider.toLowerCase(),
        'email': email.trim(),
        'name': name ?? '',
        'provider_id': providerId ?? '',
      },
    );

    final data = response.data ;
    final access = data['access'] as String?;
    final refresh = data['refresh'] as String?;

    if (access == null) {
      throw Exception('Réponse serveur invalide (token manquant)');
    }

    await _persistTokens(access, refresh);

    if (data['user'] != null) {
      _setUserAndNotify(User.fromApiJson(data['user'] ));
    } else {
      final user = await _fetchProfile();
      _setUserAndNotify(user);
    }
  }

  /// Connexion Google RÉELLE : ouvre le vrai sélecteur de compte Google
  /// natif (pas un formulaire maison), récupère un jeton d'identité signé
  /// par Google, que le backend vérifie lui-même avant de délivrer une
  /// session (voir accounts.GoogleAuthView). Remplace signInWithSocial()
  /// ci-dessus pour Google, qui reste un mode dégradé DEBUG-only.
  Future<void> signInWithGoogle() async {
    // ─── CORRECTIF : le plugin google_sign_in n'a pas d'implémentation
    // native pour Windows/Linux — l'appeler là plante avec une
    // MissingPluginException illisible pour l'utilisateur. On le bloque
    // proprement en amont avec un message clair.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      throw Exception(
        "La connexion Google n'est pas disponible sur cette plateforme. "
        "Utilisez votre email et mot de passe.",
      );
    }

    // ─── CORRECTIF : serverClientId manquant ────────────────────────────
    // Sans passer explicitement le Web Client ID Google (celui du backend,
    // voir GOOGLE_OAUTH_CLIENT_ID côté Django), le SDK google_sign_in
    // renvoie souvent un idToken NULL sur Android (l'utilisateur choisit
    // bien un compte dans le sélecteur natif, mais rien n'est renvoyé
    // ensuite à l'app — d'où l'impression de "bug bizarre" après la
    // sélection du compte). AppConfig.googleServerClientId DOIT être le
    // Web Client ID généré dans Firebase/Google Cloud Console pour ce
    // projet (PAS le client ID Android/iOS) — voir instructions dans
    // config/app_config.dart.
    final googleSignIn = GoogleSignIn(
      scopes: const ['openid', 'email', 'profile'],
      clientId: kIsWeb ? AppConfig.googleServerClientId : null,
      serverClientId: !kIsWeb && AppConfig.googleServerClientId.isNotEmpty
          ? AppConfig.googleServerClientId
          : null,
    );
    GoogleSignInAccount? account;
    try {
      account = await googleSignIn.signIn();
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_failed' && (e.message ?? '').contains('10')) {
        throw Exception(
          "Connexion Google mal configurée côté serveur (SHA-1/Client ID "
          "manquant dans la console Google Cloud). Contactez le support.",
        );
      }
      throw Exception("Connexion Google impossible : ${e.message ?? e.code}");
    }
    if (account == null) {
      // L'utilisateur a annulé la sélection de compte — pas une erreur.
      throw const SocialLoginCancelledException();
    }
    final googleAuth = await account.authentication;
    final idToken = googleAuth.idToken ?? googleAuth.accessToken;
    if (idToken == null) {
      throw Exception(
        "Google n'a pas renvoyé de jeton d'identité valide. Cela vient "
        "généralement d'une configuration Firebase/Google Cloud incomplète "
        "(SHA-1 non enregistré, ou Web Client ID absent) — réessayez plus "
        "tard ou utilisez email/mot de passe.",
      );
    }

    final response = await _apiClient.post('accounts/auth/google/', data: {'id_token': idToken});
    final data = response.data ;

    // ─── ACTIVATION PAR EMAIL OBLIGATOIRE (demande explicite) ───────────
    // Un compte créé via Google (ou jamais activé) ne reçoit AUCUN jeton :
    // le backend a envoyé un OTP par email et l'app doit basculer sur
    // l'écran de saisie du code avant toute connexion.
    if (data['email_verification_required'] == true) {
      final email = (data['email'] as String?) ?? '';
      if (email.isNotEmpty) {
        throw EmailVerificationRequiredException(email);
      }
    }

    final access = data['access'] as String?;
    if (access == null) {
      throw Exception('Réponse serveur invalide (token manquant)');
    }
    await _persistTokens(access, data['refresh'] as String?);
    if (data['user'] != null) {
      _currentUser = User.fromApiJson(data['user'] );
    } else {
      _currentUser = await _fetchProfile();
    }
    _authStateController.add(_currentUser);
  }

  /// Connexion Facebook RÉELLE : envoie le jeton d'accès Facebook au backend
  /// pour vérification cryptographique auprès de Graph API Facebook
  /// (accounts.FacebookAuthView).
  Future<void> signInWithFacebookToken(String accessToken) async {
    final response = await _apiClient.post(
      'accounts/auth/facebook/',
      data: {'access_token': accessToken},
    );
    final data = response.data;

    // Si le compte nécessite l'activation par email (OTP 15 min)
    if (data['email_verification_required'] == true) {
      final email = (data['email'] as String?) ?? '';
      if (email.isNotEmpty) {
        throw EmailVerificationRequiredException(email);
      }
    }

    final access = data['access'] as String?;
    if (access == null) {
      throw Exception('Réponse serveur invalide (token manquant)');
    }
    await _persistTokens(access, data['refresh'] as String?);
    if (data['user'] != null) {
      _currentUser = User.fromApiJson(data['user']);
    } else {
      _currentUser = await _fetchProfile();
    }
    _authStateController.add(_currentUser);
  }

  Future<void> updateProfile({
    String? username,
    String? name,
    String? phone,
    XFile? avatarFile,
    XFile? coverFile,
    String? companyName,
    String? siret,
    String? address,
    String? website,
    String? bio,
  }) async {
    dynamic dataToSend;
    if (avatarFile != null || coverFile != null) {
      final formDataMap = <String, dynamic>{};
      if (username != null) formDataMap['username'] = username;
      if (name != null) formDataMap['name'] = name;
      if (phone != null) formDataMap['phone'] = phone;
      if (companyName != null) formDataMap['publisher_profile_company_name'] = companyName;
      if (siret != null) formDataMap['publisher_profile_siret'] = siret;
      if (address != null) formDataMap['publisher_profile_address'] = address;
      if (website != null) formDataMap['publisher_profile_website'] = website;
      if (bio != null) formDataMap['publisher_profile_bio'] = bio;
      
      if (avatarFile != null) {
        final filename = avatarFile.name.isNotEmpty ? avatarFile.name : 'avatar.jpg';
        final mediaType = MediaType('image', 'jpeg');
        final bytes = await avatarFile.readAsBytes();
        formDataMap['avatar'] = MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: mediaType,
        );
      }
      // Couverture de la page publique du profil éditeur (façon TikTok) :
      // envoyée via le préfixe publisher_profile_ pour atterrir sur le
      // champ PublisherProfile.cover_image (voir UserSerializer).
      if (coverFile != null) {
        final filename = coverFile.name.isNotEmpty ? coverFile.name : 'cover.jpg';
        final mediaType = MediaType('image', 'jpeg');
        final bytes = await coverFile.readAsBytes();
        formDataMap['publisher_profile_cover_image'] = MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: mediaType,
        );
      }
      dataToSend = FormData.fromMap(formDataMap);
    } else {
      final payload = <String, dynamic>{};
      if (username != null) payload['username'] = username;
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
    _setUserAndNotify(User.fromApiJson(response.data ));
  }

  Future<void> updatePreferences(UserPreferences prefs) async {
    if (_currentUser != null) {
      _setUserAndNotify(_currentUser!.copyWith(preferences: prefs));
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

  /// Active le compte créé par inscription ou OAuth : valide le code OTP (6 chiffres,
  /// durée de vie 15 min) reçu par email. Une fois le compte activé,
  /// l'utilisateur reçoit ses tokens JWT et est connecté directement.
  Future<void> verifyEmail(String email, String code, {String? password}) async {
    final response = await _apiClient.post(
      ApiConstants.verifyEmail,
      data: {
        'email': email.trim(),
        'code': code.trim(),
        if (password != null && password.trim().isNotEmpty)
          'password': password.trim(),
      },
    );
    final data = response.data;
    if (data is Map && data['access'] != null) {
      final access = data['access'] as String;
      final refresh = data['refresh'] as String?;
      await _persistTokens(access, refresh);
      if (data['user'] != null) {
        _setUserAndNotify(User.fromApiJson(data['user']));
      } else {
        final user = await _fetchProfile();
        _setUserAndNotify(user);
      }
    }
  }

  /// Renvoie un nouveau code d'activation par email (OTP 15 min).
  Future<void> resendEmailVerificationCode(String email) async {
    await _apiClient.post(
      ApiConstants.resendEmailVerification,
      data: {'email': email.trim()},
    );
  }

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
    _setUserAndNotify(null);
    try {
      unawaited(_secureStorage.deleteAll().catchError((_) {}));
    } catch (_) {}
  }

  /// Suppression de compte en libre-service (exigence App Store 5.1.1(v) /
  /// Google Play). Le backend anonymise et désactive le compte ; on nettoie
  /// ensuite la session locale exactement comme un signOut().
  Future<void> deleteMyAccount(String password) async {
    await _apiClient.post('accounts/me/delete/', data: {'password': password});
    await signOut();
  }

  void dispose() {
    _authStateController.close();
  }
}
