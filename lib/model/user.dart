class User {
  final String id;
  final String email;
  final String username;

  /// Rôle backend : admin | publisher | reader
  final String role;
  final String? displayName;
  final String? phoneNumber;
  final String? photoUrl;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final UserStats stats;
  final UserPreferences preferences;

  // Publisher Profile details
  final String? companyName;
  final String? siret;
  final String? address;
  final String? website;
  final String? bio;

  // Informations de facturation (point 7)
  final String? billingAddress;
  final String? billingPhone;

  User({
    required this.id,
    required this.email,
    this.username = '',
    this.role = 'reader',
    this.displayName,
    this.phoneNumber,
    this.photoUrl,
    this.isVerified = false,
    required this.createdAt,
    this.lastLoginAt,
    required this.stats,
    required this.preferences,
    this.companyName,
    this.siret,
    this.address,
    this.website,
    this.bio,
    this.billingAddress,
    this.billingPhone,
  });

  bool get isAdmin => role == 'admin';
  bool get isPublisher => role == 'publisher';
  bool get isReader => role == 'reader';

  /// Mappe la réponse Django `UserSerializer` / login `user`.
  factory User.fromApiJson(Map<String, dynamic> json) {
    final dateJoined = json['date_joined'] as String?;
    final pubProfile = json['publisher_profile'] as Map<String, dynamic>?;
    final statsJson = json['stats'] as Map<String, dynamic>? ?? {};
    final prefsJson = json['preferences'] as Map<String, dynamic>? ?? {};
    return User(
      id: json['id'].toString(),
      email: json['email'] as String? ?? '',
      username: json['username'] as String? ?? '',
      role: json['role'] as String? ?? 'reader',
      displayName: json['name'] as String?,
      phoneNumber: json['phone'] as String?,
      photoUrl: json['avatar'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: dateJoined != null
          ? DateTime.tryParse(dateJoined) ?? DateTime.now()
          : DateTime.now(),
      stats: UserStats.fromJson(statsJson),
      preferences: UserPreferences.fromJson(prefsJson),
      companyName: pubProfile?['company_name'] as String?,
      siret: pubProfile?['siret'] as String?,
      address: pubProfile?['address'] as String?,
      website: pubProfile?['website'] as String?,
      bio: pubProfile?['bio'] as String?,
      billingAddress: json['billing_address'] as String?,
      billingPhone: json['billing_phone'] as String?,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
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

  User copyWith({
    String? id,
    String? email,
    String? username,
    String? role,
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    UserStats? stats,
    UserPreferences? preferences,
    String? companyName,
    String? siret,
    String? address,
    String? website,
    String? bio,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      stats: stats ?? this.stats,
      preferences: preferences ?? this.preferences,
      companyName: companyName ?? this.companyName,
      siret: siret ?? this.siret,
      address: address ?? this.address,
      website: website ?? this.website,
      bio: bio ?? this.bio,
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
