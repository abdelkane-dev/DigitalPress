class UserProfile {
  final String id;
  final String email;
  final String? displayName;
  final String? phoneNumber;
  final String? photoUrl;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final UserStats stats;
  final UserPreferences preferences;

  UserProfile({
    required this.id,
    required this.email,
    this.displayName,
    this.phoneNumber,
    this.photoUrl,
    this.isVerified = false,
    required this.createdAt,
    this.lastLoginAt,
    required this.stats,
    required this.preferences,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      photoUrl: json['photo_url'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
      stats: UserStats.fromJson(json['stats'] as Map<String, dynamic>? ?? {}),
      preferences: UserPreferences.fromJson(
        json['preferences'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'phone_number': phoneNumber,
      'photo_url': photoUrl,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
      'last_login_at': lastLoginAt?.toIso8601String(),
      'stats': stats.toJson(),
      'preferences': preferences.toJson(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    UserStats? stats,
    UserPreferences? preferences,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      stats: stats ?? this.stats,
      preferences: preferences ?? this.preferences,
    );
  }
}

class UserStats {
  final int totalPurchases;
  final int totalReads;
  final int totalBookmarks;
  final double totalSpent;
  final int readingStreak;

  UserStats({
    this.totalPurchases = 0,
    this.totalReads = 0,
    this.totalBookmarks = 0,
    this.totalSpent = 0.0,
    this.readingStreak = 0,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalPurchases: json['total_purchases'] as int? ?? 0,
      totalReads: json['total_reads'] as int? ?? 0,
      totalBookmarks: json['total_bookmarks'] as int? ?? 0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0.0,
      readingStreak: json['reading_streak'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_purchases': totalPurchases,
      'total_reads': totalReads,
      'total_bookmarks': totalBookmarks,
      'total_spent': totalSpent,
      'reading_streak': readingStreak,
    };
  }

  UserStats copyWith({
    int? totalPurchases,
    int? totalReads,
    int? totalBookmarks,
    double? totalSpent,
    int? readingStreak,
  }) {
    return UserStats(
      totalPurchases: totalPurchases ?? this.totalPurchases,
      totalReads: totalReads ?? this.totalReads,
      totalBookmarks: totalBookmarks ?? this.totalBookmarks,
      totalSpent: totalSpent ?? this.totalSpent,
      readingStreak: readingStreak ?? this.readingStreak,
    );
  }
}

class UserPreferences {
  final bool notificationsEnabled;
  final bool emailNotifications;
  final bool pushNotifications;
  final String language;
  final bool darkMode;

  UserPreferences({
    this.notificationsEnabled = true,
    this.emailNotifications = true,
    this.pushNotifications = true,
    this.language = 'fr',
    this.darkMode = false,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
      emailNotifications: json['email_notifications'] as bool? ?? true,
      pushNotifications: json['push_notifications'] as bool? ?? true,
      language: json['language'] as String? ?? 'fr',
      darkMode: json['dark_mode'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notifications_enabled': notificationsEnabled,
      'email_notifications': emailNotifications,
      'push_notifications': pushNotifications,
      'language': language,
      'dark_mode': darkMode,
    };
  }

  UserPreferences copyWith({
    bool? notificationsEnabled,
    bool? emailNotifications,
    bool? pushNotifications,
    String? language,
    bool? darkMode,
  }) {
    return UserPreferences(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      language: language ?? this.language,
      darkMode: darkMode ?? this.darkMode,
    );
  }
}
