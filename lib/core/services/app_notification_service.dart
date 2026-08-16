import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HapticFeedback, SystemSound, SystemSoundType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../api/api_client.dart';
import '../storage/secure_storage_service.dart';
import 'package:logger/logger.dart';
import '../exceptions/failures.dart';
import './auth_service.dart';
import '../../model/user.dart';
import '../../config/api_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modèle
// ─────────────────────────────────────────────────────────────────────────────

class AppNotification {
  final int id;
  final String typeNotif;
  final String typeNotifDisplay;
  final String title;
  final String message;
  final bool isRead;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.typeNotif,
    required this.typeNotifDisplay,
    required this.title,
    required this.message,
    required this.isRead,
    required this.data,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? 0,
      typeNotif: json['type_notif'] ?? 'system',
      typeNotifDisplay: json['type_notif_display'] ?? 'Système',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      isRead: json['is_read'] ?? false,
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data']) : {},
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      typeNotif: typeNotif,
      typeNotifDisplay: typeNotifDisplay,
      title: title,
      message: message,
      isRead: isRead ?? this.isRead,
      data: data,
      createdAt: createdAt,
    );
  }

  /// Retourne l'icône correspondant au type de notification.
  IconData get icon {
    switch (typeNotif) {
      case 'payment_success':
        return Icons.check_circle_rounded;
      case 'payment_failed':
        return Icons.cancel_rounded;
      case 'subscription_activated':
        return Icons.subscriptions_rounded;
      case 'subscription_expired':
        return Icons.hourglass_empty_rounded;
      case 'withdrawal_approved':
      case 'withdrawal_completed':
        return Icons.account_balance_wallet_rounded;
      case 'withdrawal_rejected':
        return Icons.money_off_rounded;
      case 'new_publication':
        return Icons.fiber_new_rounded;
      case 'verification_reviewed':
        return Icons.verified_rounded;
      case 'verification_submitted':
        return Icons.pending_actions_rounded;
      case 'system':
      default:
        return Icons.notifications_rounded;
    }
  }

  Color get color {
    switch (typeNotif) {
      case 'payment_success':
      case 'subscription_activated':
      case 'withdrawal_approved':
      case 'withdrawal_completed':
      case 'verification_reviewed':
        return const Color(0xFF10B981);
      case 'payment_failed':
      case 'subscription_expired':
      case 'withdrawal_rejected':
        return const Color(0xFFEF4444);
      case 'new_publication':
        return const Color(0xFF2C74B3);
      case 'verification_submitted':
        return const Color(0xFFF59E0B);
      case 'system':
      default:
        return const Color(0xFF8B5CF6);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StateNotifier
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsNotifier
    extends StateNotifier<AsyncValue<List<AppNotification>>> {
  final ApiClient _api;
  final Ref _ref;
  final _logger = Logger();
  Timer? _pollingTimer;
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  Timer? _wsReconnectTimer;
  int _pingSeq = 0;
  int _consecutiveNetworkErrors = 0;
  static const int _maxNetworkErrorRetries = 3;
  /// Garde contre les doubles initialisations lors d'émissions redondantes
  /// de authStateProvider.
  bool _initialized = false;

  NotificationsNotifier(this._api, this._ref)
      : super(const AsyncValue.loading()) {
    // Écoute les changements d'état d'authentification pour démarrer/arrêter
    // le WebSocket temps réel (+ le polling de secours) lorsque
    // l'utilisateur se connecte/déconnecte.
    _ref.listen<AsyncValue<User?>>(authStateProvider, (prev, next) {
      final user = next.asData?.value;
      if (user != null) {
        if (!_initialized) _initialize();
      } else {
        _initialized = false;
        _pollingTimer?.cancel();
        _disconnectWebSocket();
        state = const AsyncValue.data([]);
      }
    }, fireImmediately: true);
  }

  Future<void> _initialize() async {
    _initialized = true;
    final token = await _ref.read(secureStorageServiceProvider).getToken();
    _logger.i(
        'NotificationsNotifier._initialize token present=${token != null && token.isNotEmpty}');
    if (token == null || token.isEmpty) {
      _initialized = false;
      _logger.i('No token found — notifications polling will not start');
      state = const AsyncValue.data([]);
      return;
    }
    _logger.i('Token found — performing initial load, connecting WebSocket');
    load();
    _connectWebSocket(token);
    // Le polling est un filet de secours derrière le WebSocket.
    // Intervalle de 60s pour minimiser les requêtes réseau superflues.
    _startPolling();
  }

  /// Notifications en temps réel : dès qu'une Notification est créée côté
  /// backend, elle arrive ici instantanément via WebSocket.
  void _connectWebSocket(String token) {
    _disconnectWebSocket();
    final base = ApiConfig.wsBaseUrl;
    if (base.isEmpty) return;

    try {
      final uri = Uri.parse('$base/ws/notifications/?token=$token');
      _wsChannel = WebSocketChannel.connect(uri);
      _wsChannel!.ready.catchError((e) {
        _logger.w('WebSocket notifications non disponible ($e)');
      });
      _wsSubscription = _wsChannel!.stream.listen(
        (raw) {
          try {
            final json = jsonDecode(raw as String) as Map<String, dynamic>;
            if (json.containsKey('id') && json.containsKey('title')) {
              // Vraie Notification persistée en base.
              final notif = AppNotification.fromJson(json);
              var isNew = false;
              state.whenData((list) {
                if (list.any((n) => n.id == notif.id)) return;
                isNew = true;
                state = AsyncValue.data([notif, ...list]);
              });
              // Alerte temps réel (vibration + son) pour une notification
              // qui vient d'arriver (demande explicite, façon WhatsApp).
              if (isNew) _playRealtimeAlert();
              // ─── SYNCHRO TEMPS RÉEL DU PROFIL ────────────────────────
              // Toute notification = le profil a changé quelque part
              // (vérification, palier, solde, retrait, stats, mot de passe,
              // infos perso/éditeur...) : on rafraîchit le profil à chaque
              // notification reçue pour que les infos perso et le profil
              // éditeur restent synchronisés en temps réel, sans avoir à se
              // déconnecter/reconnecter.
              _ref.read(authServiceProvider).refreshProfile();
            } else if (json.containsKey('event')) {
              // Événement temps réel générique (favoris, stats...).
              _pingSeq++;
              _ref.read(realtimeEventProvider.notifier).state =
                  RealtimeEvent(json['event'] as String, json, _pingSeq);
              if (json['event'] == 'stats_changed') {
                // Alerte temps réel : un paiement/revenu vient d'arriver
                // (demande explicite : son + vibration, façon WhatsApp).
                _playRealtimeAlert();
                _ref.read(authServiceProvider).refreshProfile();
              }
            }
          } catch (e) {
            _logger.w('Message WebSocket notifications illisible : $e');
          }
        },
        onError: (e) {
          _logger.w('Erreur WebSocket notifications : $e — reconnexion différée');
          _scheduleWebSocketReconnect(token);
        },
        onDone: () {
          _logger.i('WebSocket notifications fermé — reconnexion différée');
          _scheduleWebSocketReconnect(token);
        },
        cancelOnError: true,
      );
    } catch (e) {
      _logger.w('Impossible de se connecter au WebSocket notifications : $e');
      _scheduleWebSocketReconnect(token);
    }
  }

  void _scheduleWebSocketReconnect(String token) {
    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = Timer(const Duration(seconds: 10), () {
      _connectWebSocket(token);
    });
  }

  void _disconnectWebSocket() {
    _wsReconnectTimer?.cancel();
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    _wsChannel = null;
  }

  /// Alerte « façon WhatsApp » : petite vibration + son bref, jouée UNIQUEMENT
  /// quand un événement temps réel arrive via WebSocket (nouvelle notification
  /// ou stats_changed) — jamais pendant le polling de secours. Silencieuse en
  /// cas d'échec (confort, jamais une fatalité).
  void _playRealtimeAlert() {
    try {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    // Filet de secours derrière le WebSocket.
    // 60 secondes pour minimiser les requêtes réseau superflues.
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      load(isBackground: true);
    });
  }

  Future<void> load({bool isBackground = false}) async {
    final token = await _ref.read(secureStorageServiceProvider).getToken();
    if (token == null || token.isEmpty) {
      _pollingTimer?.cancel();
      state = const AsyncValue.data([]);
      return;
    }

    if (!isBackground) {
      state = const AsyncValue.loading();
    }

    try {
      final response = await _api.get('notifications/');
      _consecutiveNetworkErrors = 0;
      final List<dynamic> raw = response.data is Map
          ? (response.data['results'] as List? ?? [])
          : (response.data as List? ?? []);
      final list = raw
          .map((j) => AppNotification.fromJson(j as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      _logger.e('Erreur chargement notifications : $e');
      if (e is AuthFailure) {
        _logger.w('AuthFailure received — stopping notifications polling');
        _pollingTimer?.cancel();
        state = const AsyncValue.data([]);
        return;
      }
      _consecutiveNetworkErrors += 1;
      if (_consecutiveNetworkErrors >= _maxNetworkErrorRetries) {
        _logger.w(
          'Network error threshold reached ($_consecutiveNetworkErrors) — stopping notifications polling',
        );
        _pollingTimer?.cancel();
        state = AsyncValue.error(e, st);
        return;
      }
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markAsRead(int id) async {
    try {
      await _api.post('notifications/$id/mark-read/');
      state.whenData((list) {
        state = AsyncValue.data(
          list.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList(),
        );
      });
    } catch (e) {
      _logger.e('Erreur marquage notification $id : $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _api.post('notifications/mark-read/');
      state.whenData((list) {
        state =
            AsyncValue.data(list.map((n) => n.copyWith(isRead: true)).toList());
      });
    } catch (e) {
      _logger.e('Erreur marquage toutes notifications : $e');
    }
  }

  /// Supprime une notification côté serveur puis localement.
  Future<void> deleteNotification(int id) async {
    try {
      await _api.delete('notifications/$id/');
    } catch (e) {
      _logger.e('Erreur suppression notification $id : $e');
    }
    state.whenData((list) {
      state = AsyncValue.data(list.where((n) => n.id != id).toList());
    });
  }

  /// Supprime TOUTES les notifications de l'utilisateur (mise à zéro).
  Future<void> clearAllNotifications() async {
    try {
      await _api.delete('notifications/delete-all/');
    } catch (e) {
      _logger.e('Erreur suppression de toutes les notifications : $e');
    }
    state = const AsyncValue.data([]);
  }

  void removeLocally(int id) {
    state.whenData((list) {
      state = AsyncValue.data(list.where((n) => n.id != id).toList());
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _disconnectWebSocket();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Bus d'événements temps réel générique (favoris, statistiques...), pour
/// tout ce qui n'est PAS une Notification persistée en base. Alimenté par
/// NotificationsNotifier dès qu'un message WebSocket de type "ping" arrive.
/// D'autres providers s'y abonnent avec `ref.listen` pour se recharger
/// automatiquement.
class RealtimeEvent {
  final String event;
  final Map<String, dynamic> data;
  final int seq; // incrémente à chaque événement, même si `event` se répète
  const RealtimeEvent(this.event, this.data, this.seq);
}

final realtimeEventProvider = StateProvider<RealtimeEvent?>((ref) => null);

final appNotificationsProvider = StateNotifierProvider<NotificationsNotifier,
    AsyncValue<List<AppNotification>>>((ref) {
  final api = ref.watch(apiClientProvider);
  return NotificationsNotifier(api, ref);
});

final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(appNotificationsProvider).maybeWhen(
        data: (list) => list.where((n) => !n.isRead).length,
        orElse: () => 0,
      );
});
