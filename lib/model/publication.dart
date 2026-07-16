import '../config/api_config.dart';

/// Modèle unifié pour les publications/contenus de Digital Press.
/// Fusionne ContenuModel (ancienne architecture) et Journal (nouvelle).
/// Mappe directement la réponse du backend Django (PublicationSerializer).
class Publication {
  final int id;
  final String title;
  final String subtitle;
  final String description;
  final String content;

  // Publisher info
  final int publisherId;
  final String publisherName;

  // Category
  final int? categoryId;
  final String? categoryName;

  // Media
  final String coverImage;
  final String fileUrl;
  final String videoUrl;

  // Pricing
  final double prix;
  final bool isFree;

  // Meta
  final String status;
  final String pubType;
  final int viewsCount;
  final int downloadsCount;
  final List<String> tags;
  final double? averageRating;
  final int reviewsCount;
  final bool isSubscribed;  // Calculé par le backend selon l'abonnement actif
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Publication({
    required this.id,
    required this.title,
    this.subtitle = '',
    required this.description,
    this.content = '',
    required this.publisherId,
    this.publisherName = '',
    this.categoryId,
    this.categoryName,
    this.coverImage = '',
    this.fileUrl = '',
    this.videoUrl = '',
    this.prix = 0.0,
    this.isFree = false,
    this.status = 'published',
    this.pubType = 'article',
    this.viewsCount = 0,
    this.downloadsCount = 0,
    this.tags = const [],
    this.averageRating,
    this.reviewsCount = 0,
    this.isSubscribed = false,
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory Publication.fromJson(Map<String, dynamic> json) {
    // Handle tags: can be a list or a comma-separated string
    List<String> tagsList = [];
    final rawTags = json['tags_list'] ?? json['tags'];
    if (rawTags is List) {
      tagsList = rawTags.map((e) => e.toString()).toList();
    } else if (rawTags is String && rawTags.isNotEmpty) {
      tagsList = rawTags.split(',').map((s) => s.trim()).toList();
    }

    return Publication(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      description: json['description'] ?? '',
      content: json['content'] ?? '',
      publisherId: json['publisher'] is Map
          ? (json['publisher']['id'] ?? 0)
          : (json['publisher'] ?? 0),
      publisherName: json['publisher_name'] ??
          (json['publisher'] is Map ? json['publisher']['name'] ?? '' : ''),
      categoryId: json['category'] is Map
          ? json['category']['id']
          : json['category'],
      categoryName: json['category_name'] ??
          (json['category'] is Map ? json['category']['name'] : null),
      coverImage: ApiConfig.sanitizeUrl(json['cover_image'] ?? json['image_url'] ?? ''),
      fileUrl: ApiConfig.sanitizeUrl(json['file_url'] ?? json['pdf_url'] ?? ''),
      videoUrl: ApiConfig.sanitizeUrl(json['video_url'] ?? ''),
      prix: double.tryParse(json['prix']?.toString() ?? '0') ??
          (json['price'] as num?)?.toDouble() ??
          0.0,
      isFree: json['is_free'] ?? false,
      status: json['status'] ?? 'published',
      pubType: json['pub_type'] ?? json['type'] ?? 'article',
      viewsCount: json['views_count'] ?? 0,
      downloadsCount: json['downloads_count'] ?? 0,
      tags: tagsList,
      averageRating: json['average_rating'] != null
          ? double.tryParse(json['average_rating'].toString())
          : null,
      reviewsCount: json['reviews_count'] ?? 0,
      isSubscribed: json['is_subscribed'] ?? false,
      publishedAt: _parseDate(json['published_date'] ?? json['published_at']),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'description': description,
        'publisher': publisherId,
        'category': categoryId,
        'cover_image': coverImage,
        'file_url': fileUrl,
        'video_url': videoUrl,
        'prix': prix,
        'is_free': isFree,
        'status': status,
        'pub_type': pubType,
        'tags': tags.join(','),
      };

  // Convenience getters
  bool get isPublished => status == 'published';
  bool get isDraft => status == 'draft';
  bool get isPending => status == 'pending';

  String get prixDisplay => isFree ? 'Gratuit' : '${prix.toStringAsFixed(0)} FCFA';

  String get typeLabel {
    switch (pubType) {
      case 'article': return 'Article';
      case 'magazine': return 'Magazine';
      case 'journal': return 'Journal';
      case 'report': return 'Rapport';
      case 'ebook': return 'E-book';
      default: return pubType;
    }
  }

  Publication copyWith({
    int? id,
    String? title,
    String? subtitle,
    String? description,
    String? content,
    int? publisherId,
    String? publisherName,
    int? categoryId,
    String? categoryName,
    String? coverImage,
    String? fileUrl,
    String? videoUrl,
    double? prix,
    bool? isFree,
    String? status,
    String? pubType,
    int? viewsCount,
    int? downloadsCount,
    List<String>? tags,
    double? averageRating,
    int? reviewsCount,
    DateTime? publishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Publication(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      content: content ?? this.content,
      publisherId: publisherId ?? this.publisherId,
      publisherName: publisherName ?? this.publisherName,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      coverImage: coverImage ?? this.coverImage,
      fileUrl: fileUrl ?? this.fileUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      prix: prix ?? this.prix,
      isFree: isFree ?? this.isFree,
      status: status ?? this.status,
      pubType: pubType ?? this.pubType,
      viewsCount: viewsCount ?? this.viewsCount,
      downloadsCount: downloadsCount ?? this.downloadsCount,
      tags: tags ?? this.tags,
      averageRating: averageRating ?? this.averageRating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
