class AppConfig {
  static const String appName = 'DigitalPress';
  static const String appVersion = '1.0.0';

  // ─── Backend API URLs ────────────────────────────────────────────────────────
  //
  // HOW TO CONFIGURE:
  //
  // 1. LOCAL DEVELOPMENT (Android emulator → Django on same machine)
  //    baseUrl = 'http://10.0.2.2:8000/api/'
  //
  // 2. LOCAL DEVELOPMENT (Real device → Django on same WiFi)
  //    baseUrl = 'http://192.168.1.XX:8000/api/'   ← replace with your PC's LAN IP
  //
  // 3. WEB PREVIEW in sandbox / production server
  //    baseUrlWeb = 'http://YOUR_SERVER_IP:8000/api/'
  //    Example: 'http://203.0.113.10:8000/api/'
  //
  // 4. PRODUCTION with domain + HTTPS
  //    baseUrl = baseUrlWeb = 'https://api.yoursite.com/api/'
  //
  // ⚠️  'localhost' / '127.0.0.1' in baseUrlWeb will NEVER work from a browser
  //     that is NOT on the same machine as the Django server.
  // ────────────────────────────────────────────────────────────────────────────

  /// URL par défaut — en production (builds release, web, natives) TOUTES
  /// les plateformes utilisent le nom de domaine officiel en HTTPS, jamais
  /// l'IP brute du VPS ni localhost. En développement local, passez une
  /// adresse locale via --dart-define=API_BASE_URL=... (voir api_config.dart).
  static const String baseUrl = 'https://www.digitalpress-ml.com/api/';

  /// Localhost for iOS simulator, Windows, macOS, Linux, and Android with adb reverse
  static const String baseUrlLocal = 'http://localhost:8000/api/';

  /// Web build & Production API — nom de domaine officiel en HTTPS.
  /// ⚠️ TOUJOURS avec le préfixe `www` : le domaine nu (digitalpress-ml.com)
  /// passe par le proxy anti-DDoS de l'hébergeur (en-têtes X-Anubis) qui
  /// renvoie 404 — seul www.digitalpress-ml.com atteint directement le VPS.
  static const String baseUrlWeb = 'https://www.digitalpress-ml.com/api/';

  // CinetPay (passerelle de paiement unifiée — mobile money + cartes)
  // Les clés réelles sont gérées côté backend (.env) : CINETPAY_API_KEY,
  // CINETPAY_SITE_ID, CINETPAY_SECRET. L'app ne fait qu'envoyer le moyen
  // choisi ; le backend ouvre la page de paiement CinetPay hébergée.
  static const String cinetpayApiKey = 'YOUR_CINETPAY_KEY';
  static const String cinetpayBaseUrl = 'https://api-checkout.cinetpay.com/v2';

  // ─── Google Sign-In ──────────────────────────────────────────────────────
  // Web Client ID (PAS le client ID Android/iOS) généré dans Firebase
  // Console > Authentication > Sign-in method > Google, ou dans Google
  // Cloud Console > Identifiants > ID client OAuth 2.0 > type "Application
  // Web". Doit être IDENTIQUE à GOOGLE_OAUTH_CLIENT_ID côté backend Django
  // (.env), sinon le backend rejettera le jeton (audience différente).
  //
  // ⚠️ À la date de cet audit, android/app/google-services.json ne contient
  // AUCUN "oauth_client" enregistré (liste vide) : cela signifie que la
  // console Firebase/Google Cloud n'a pas encore l'empreinte SHA-1 de
  // signature de cette app Android, ni de Web Client ID généré pour ce
  // projet. C'est la cause la plus probable du bug "le sélecteur de compte
  // Google s'affiche, on choisit un compte, puis une erreur apparaît" :
  // tant que ce qui suit n'est pas fait, aucune valeur ici ne résoudra le
  // problème.
  //   1. Générer le SHA-1 (et SHA-256) du keystore de signature Android :
  //      `keytool -list -v -keystore <votre.keystore> -alias <alias>`
  //   2. Firebase Console > Paramètres du projet > Vos applications >
  //      ajouter une app Android avec le package "com.digitalpress.app"
  //      (nouveau nom — voir remarque ci-dessous) > y ajouter l'empreinte
  //      SHA-1.
  //   3. Authentication > Sign-in method > activer "Google".
  //   4. Relancer `flutterfire configure`, ou retélécharger manuellement
  //      google-services.json (Android) et GoogleService-Info.plist (iOS)
  //      mis à jour, et remplacer les fichiers dans android/app/ et
  //      ios/Runner/.
  //   5. Copier le "Web Client ID" généré ici ET dans GOOGLE_OAUTH_CLIENT_ID
  //      côté backend (.env sur le VPS), puis redémarrer le service Django.
  //
  // ⚠️ Le package Android/iOS est désormais "com.digitalpress.app" (corrigé
  // le 2026-08-14, voir android/app/build.gradle.kts et
  // PRODUCT_BUNDLE_IDENTIFIER côté iOS — l'ancien "com.example.digitalpress"
  // était refusé par le Play Store). Mais google-services.json,
  // GoogleService-Info.plist et lib/firebase_options.dart référencent
  // ENCORE l'ancien package côté Firebase : l'étape 2 ci-dessus doit
  // utiliser le NOUVEAU package pour que tout se recorresponde.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '601381319647-jf28ssa1sde4h9aflpsheqvl7defncie.apps.googleusercontent.com',
  );

  // Commission platform (10 %)
  static const double commissionRate = 0.10;

  // Pagination
  static const int pageSize = 10;
}
