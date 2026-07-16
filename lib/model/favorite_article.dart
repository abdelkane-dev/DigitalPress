/// Article mis en favori par le Lecteur, avec la liste des catégories
/// personnelles (playlists) dans lesquelles il est rangé.
class FavoriteArticle {
  final int id;
  final String title;
  final String description;
  final String coverImage;
  final List<int> categoryIds;
  final DateTime addedAt;

  FavoriteArticle({
    required this.id,
    required this.title,
    required this.description,
    required this.coverImage,
    required this.categoryIds,
    required this.addedAt,
  });

  factory FavoriteArticle.fromJson(Map<String, dynamic> json) {
    return FavoriteArticle(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      coverImage: json['cover_image'] as String? ?? '',
      categoryIds: (json['category_ids'] as List? ?? []).map((e) => e as int).toList(),
      addedAt: DateTime.parse(json['added_at'] as String),
    );
  }
}
