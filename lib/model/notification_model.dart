import 'package:flutter/material.dart';

enum NotificationType { payment, newJournal, promotion, reminder, system }

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final String category;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? data;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.category,
    required this.timestamp,
    this.isRead = false,
    this.data,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: _getTypeFromString(json['type'] as String),
      category: json['category'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['is_read'] as bool? ?? false,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': _getTypeString(type),
      'category': category,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead,
      'data': data,
    };
  }

  static NotificationType _getTypeFromString(String type) {
    switch (type.toLowerCase()) {
      case 'payment':
        return NotificationType.payment;
      case 'new_journal':
        return NotificationType.newJournal;
      case 'promotion':
        return NotificationType.promotion;
      case 'reminder':
        return NotificationType.reminder;
      default:
        return NotificationType.system;
    }
  }

  static String _getTypeString(NotificationType type) {
    switch (type) {
      case NotificationType.payment:
        return 'payment';
      case NotificationType.newJournal:
        return 'new_journal';
      case NotificationType.promotion:
        return 'promotion';
      case NotificationType.reminder:
        return 'reminder';
      case NotificationType.system:
        return 'system';
    }
  }

  IconData get icon {
    switch (type) {
      case NotificationType.payment:
        return Icons.check_circle_rounded;
      case NotificationType.newJournal:
        return Icons.fiber_new_rounded;
      case NotificationType.promotion:
        return Icons.local_offer_rounded;
      case NotificationType.reminder:
        return Icons.schedule_rounded;
      case NotificationType.system:
        return Icons.info_rounded;
    }
  }

  Color get color {
    switch (type) {
      case NotificationType.payment:
        return const Color(0xFF10B981);
      case NotificationType.newJournal:
        return const Color(0xFF2C74B3);
      case NotificationType.promotion:
        return const Color(0xFFF59E0B);
      case NotificationType.reminder:
        return const Color(0xFF8B5CF6);
      case NotificationType.system:
        return const Color(0xFF64748B);
    }
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    String? category,
    DateTime? timestamp,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
    );
  }
}
