import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import '../api/api_client.dart';
import '../../config/api_constants.dart';

/// Handler global pour les messages reçus quand l'app est fermée ou en arrière-plan.
/// DOIT être une fonction de haut niveau (pas une méthode de classe).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('[FCM Background] Message reçu : ${message.messageId}');
  }
}

// ---------------------------------------------------------------------------
// Navigation depuis une notification (quand l'app est fermée/background)
// On stocke le router GoRouter dès que l'app est lancée pour pouvoir naviguer
// depuis le service de notifications sans accès au BuildContext.
// ---------------------------------------------------------------------------
class NotificationNavigator {
  static GoRouter? _router;

  static void setRouter(GoRouter router) {
    _router = router;
  }

  static void goTo(String path) {
    try {
      _router?.push(path);
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationNavigator] Erreur navigation : $e');
    }
  }
}

// ---------------------------------------------------------------------------
// Provider Riverpod
// ---------------------------------------------------------------------------
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return NotificationService(apiClient);
});

/// Service gérant les notifications push Firebase Cloud Messaging (FCM).
///
/// Responsabilités :
///   1. Demander la permission de notifications à l'utilisateur.
///   2. Obtenir le token FCM et l'enregistrer sur le backend.
///   3. Afficher une notification locale quand l'app est en premier plan.
///   4. Naviguer vers l'article concerné quand l'utilisateur tape la notification.
class NotificationService {
  final ApiClient _apiClient;
  final _fcm = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _logger = Logger();

  NotificationService(this._apiClient);

  /// Canal Android haute importance (requis pour Android 8+).
  static const _androidChannel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Canal utilisé pour les notifications importantes de DigitalPress.',
    importance: Importance.max,
    playSound: true,
  );

  // ---------------------------------------------------------------------------
  // Initialisation principale — appeler après la connexion de l'utilisateur.
  // ---------------------------------------------------------------------------
  Future<void> init() async {
    // ── 0. Initialisation des notifications locales ────────────────────────
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // L'utilisateur a tapé la notification quand l'app était en premier plan.
        _navigateFromPayload(details.payload);
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // ── 1. Handler background (doit être enregistré très tôt) ─────────────
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // ── 2. Demande de permission ───────────────────────────────────────────
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      provisional: false,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      _logger.w('[FCM] Permissions refusées par l\'utilisateur.');
      return;
    }

    _logger.i('[FCM] Permissions accordées.');

    // ── 3. Token FCM → enregistrement backend ─────────────────────────────
    final token = await _fcm.getToken();
    if (token != null) {
      await _registerTokenWithBackend(token);
    }

    // Renouvellement automatique du token (ex: réinstallation de l'app).
    _fcm.onTokenRefresh.listen((newToken) async {
      _logger.i('[FCM] Token renouvelé.');
      await _registerTokenWithBackend(newToken);
    });

    // ── 4. Message reçu en PREMIER PLAN → notification locale ─────────────
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _logger.i('[FCM] Message premier plan : ${message.notification?.title}');
      final notification = message.notification;
      if (notification == null) return;

      final articleId = message.data['article_id'];
      final payload = articleId != null ? '/article/$articleId' : null;

      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            icon: notification.android?.smallIcon ?? '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    });

    // ── 5. L'utilisateur tape la notification — app en ARRIÈRE-PLAN ────────
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _logger.i('[FCM] Notification tapée (background).');
      final articleId = message.data['article_id'];
      if (articleId != null) {
        NotificationNavigator.goTo('/article/$articleId?scrollToComments=true');
      }
    });

    // ── 6. L'app a été FERMÉE puis relancée via une notification ──────────
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _logger.i('[FCM] App lancée via notification.');
      final articleId = initialMessage.data['article_id'];
      if (articleId != null) {
        // Petite attente pour laisser l'UI se construire.
        await Future.delayed(const Duration(milliseconds: 800));
        NotificationNavigator.goTo('/article/$articleId?scrollToComments=true');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Enregistrement du token FCM sur le backend Django.
  // ---------------------------------------------------------------------------
  Future<void> _registerTokenWithBackend(String token) async {
    try {
      await _apiClient.post(
        ApiConstants.registerFcm,
        data: {'token': token, 'device_type': 'android'},
      );
      _logger.i('[FCM] Token enregistré sur le backend.');
    } catch (e) {
      _logger.e('[FCM] Erreur enregistrement token : $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation depuis un payload de notification locale.
  // ---------------------------------------------------------------------------
  void _navigateFromPayload(String? payload) {
    if (payload == null) return;
    // payload format : '/article/42'
    NotificationNavigator.goTo('$payload?scrollToComments=true');
  }

  // ---------------------------------------------------------------------------
  // Abonnement à un sujet FCM (ex: 'news').
  // ---------------------------------------------------------------------------
  Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
    _logger.i('[FCM] Abonné au sujet : $topic');
  }

  /// Désabonnement d'un sujet FCM.
  Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
    _logger.i('[FCM] Désabonné du sujet : $topic');
  }
}
