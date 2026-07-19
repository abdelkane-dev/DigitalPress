/// Catégorie personnelle créée par un Lecteur pour organiser ses favoris,
/// comme une playlist YouTube. N'a aucun rapport avec les catégories
/// globales gérées par les éditeurs/admin.
class ReaderCategory {
  final int id;
  final String name;
  final DateTime createdAt;
  final int articlesCount;

  ReaderCategory({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.articlesCount,
  });

  factory ReaderCategory.fromJson(Map<String, dynamic> json) {
    return ReaderCategory(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      articlesCount: json['articles_count'] as int? ?? 0,
    );
  }
}
