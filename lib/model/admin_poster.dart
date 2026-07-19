import 'poster_warning.dart';

class AdminPoster {
  final String id;
  final String fullName;
  final String mediaName;
  final String email;
  final int warnings;
  final bool isBanned;
  final List<PosterWarning> warningHistory;

  final int totalArticles;
  final int publishedArticles;
  final int draftArticles;
  final int totalViews;
  final double commissionRate;

  const AdminPoster({
    required this.id,
    required this.fullName,
    required this.mediaName,
    required this.email,
    required this.warnings,
    required this.isBanned,
    this.warningHistory = const [],
    this.totalArticles = 0,
    this.publishedArticles = 0,
    this.draftArticles = 0,
    this.totalViews = 0,
    this.commissionRate = 10.0,
  });

  AdminPoster copyWith({
    String? id,
    String? fullName,
    String? mediaName,
    String? email,
    int? warnings,
    bool? isBanned,
    List<PosterWarning>? warningHistory,
    int? totalArticles,
    int? publishedArticles,
    int? draftArticles,
    int? totalViews,
    double? commissionRate,
  }) {
    return AdminPoster(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      mediaName: mediaName ?? this.mediaName,
      email: email ?? this.email,
      warnings: warnings ?? this.warnings,
      isBanned: isBanned ?? this.isBanned,
      warningHistory: warningHistory ?? this.warningHistory,
      totalArticles: totalArticles ?? this.totalArticles,
      publishedArticles: publishedArticles ?? this.publishedArticles,
      draftArticles: draftArticles ?? this.draftArticles,
      totalViews: totalViews ?? this.totalViews,
      commissionRate: commissionRate ?? this.commissionRate,
    );
  }
}