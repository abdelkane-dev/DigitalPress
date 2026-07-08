import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

/// Fonction de haut niveau pour gérer les messages en arrière-plan.
/// Doit être en dehors de toute classe pour être accessible par l'Isolate Firebase.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Si vous avez besoin d'initialiser Firebase ici, faites-le :
  // await Firebase.initializeApp();
  if (kDebugMode) {
    print("Message en arrière-plan reçu : ${message.messageId}");
  }
}

/// Fournisseur pour le service de notifications push via Firebase Cloud Messaging (FCM).
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Service gérant la réception des notifications et l'abonnement aux topics.
class NotificationService {
  final _fcm = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _logger = Logger();

  /// Canal de notification pour Android (nécessaire pour le premier plan).
  static const _androidChannel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Ce canal est utilisé pour les notifications importantes.',
    importance: Importance.max,
  );

  /// Initialise le service, demande les permissions et configure les écouteurs.
  Future<void> init() async {
    // 0. Initialisation des notifications locales (pour le premier plan Android)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(initSettings);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);

    // 1. Configurer le handler de background (doit être fait tôt)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Demander les permissions (obligatoire sur iOS/Android 13+)
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      _logger.i('Permissions de notifications accordées');

      // 3. Récupérer le Token FCM (à envoyer à votre backend)
      final token = await _fcm.getToken();
      _logger.i('Token FCM : $token');

      // 4. Gérer les messages quand l'app est au premier plan
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        final android = message.notification?.android;

        if (notification != null && android != null && !kIsWeb) {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                _androidChannel.id,
                _androidChannel.name,
                channelDescription: _androidChannel.description,
                icon: android.smallIcon,
              ),
            ),
          );
        }

        _logger.i('Notification reçue au premier plan !');
        _logger.i('Contenu : ${notification?.title} - ${notification?.body}');
      });

      // 5. Gérer le clic sur une notification quand l'app est en background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _logger.i('L\'utilisateur a cliqué sur la notification !');
        // Naviguer vers une page spécifique si nécessaire
      });

      // 6. Gérer l'ouverture de l'app via une notification (quand l'app était fermée)
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _logger.i(
          'App lancée via une notification : ${initialMessage.messageId}',
        );
      }
    } else {
      _logger.w('Permissions de notifications refusées ou non accordées');
    }
  }

  /// S'abonner à un sujet spécifique (ex: 'news', 'promotions').
  Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
    _logger.i('Abonné au sujet : $topic');
  }
}
