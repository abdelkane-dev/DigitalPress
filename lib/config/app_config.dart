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

  /// Android emulator -> 10.0.2.2 points to host's localhost
  static const String baseUrl = 'http://192.168.1.2:8000/api/';

  /// Localhost for iOS simulator, Windows, macOS, Linux, and Android with adb reverse
  static const String baseUrlLocal = 'http://localhost:8000/api/';

  /// Web build
  static const String baseUrlWeb = 'http://localhost:8000/api/';

  // Movapay
  static const String movapayApiKey = 'YOUR_MOVAPAY_KEY';
  static const String movapayBaseUrl = 'https://api.movapay.com/v1/';

  // Commission platform (10 %)
  static const double commissionRate = 0.10;

  // Pagination
  static const int pageSize = 10;
}
