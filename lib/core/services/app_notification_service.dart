import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import 'package:logger/logger.dart';

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

  /// Retourne l'icône et la couleur correspondant au type de notification.
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
        return const Color(0xFF10B981);
      case 'payment_failed':
      case 'subscription_expired':
      case 'withdrawal_rejected':
        return const Color(0xFFEF4444);
      case 'new_publication':
        return const Color(0xFF2C74B3);
      case 'system':
      default:
        return const Color(0xFF8B5CF6);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StateNotifier
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsNotifier extends StateNotifier<AsyncValue<List<AppNotification>>> {
  final ApiClient _api;
  final _logger = Logger();

  NotificationsNotifier(this._api) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final response = await _api.get('notifications/');
      final List<dynamic> raw = response.data is Map
          ? (response.data['results'] as List? ?? [])
          : (response.data as List? ?? []);
      final list = raw
          .map((j) => AppNotification.fromJson(j as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      _logger.e('Erreur chargement notifications : $e');
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
        state = AsyncValue.data(list.map((n) => n.copyWith(isRead: true)).toList());
      });
    } catch (e) {
      _logger.e('Erreur marquage toutes notifications : $e');
    }
  }

  void removeLocally(int id) {
    state.whenData((list) {
      state = AsyncValue.data(list.where((n) => n.id != id).toList());
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final appNotificationsProvider =
    StateNotifierProvider<NotificationsNotifier, AsyncValue<List<AppNotification>>>((ref) {
  final api = ref.watch(apiClientProvider);
  return NotificationsNotifier(api);
});

final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(appNotificationsProvider).maybeWhen(
        data: (list) => list.where((n) => !n.isRead).length,
        orElse: () => 0,
      );
});
