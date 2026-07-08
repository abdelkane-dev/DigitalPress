class PosterArticle {
  final String id;
  final String title;
  final String category;
  final String summary;
  final String content;
  final String status; // draft | published
  final int views;
  final DateTime createdAt;
  final String? coverImagePath;

  const PosterArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.content,
    required this.status,
    required this.views,
    required this.createdAt,
    this.coverImagePath,
  });

  PosterArticle copyWith({
    String? id,
    String? title,
    String? category,
    String? summary,
    String? content,
    String? status,
    int? views,
    DateTime? createdAt,
    String? coverImagePath,
  }) {
    return PosterArticle(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      summary: summary ?? this.summary,
      content: content ?? this.content,
      status: status ?? this.status,
      views: views ?? this.views,
      createdAt: createdAt ?? this.createdAt,
      coverImagePath: coverImagePath ?? this.coverImagePath,
    );
  }
}