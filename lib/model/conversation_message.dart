/// Un message unifié dans la conversation d'un article : soit un avis noté
/// par étoiles (le premier message que poste chaque utilisateur), soit une
/// réponse libre façon commentaire Facebook (avec réponses en fil).
class ConversationMessage {
  final String id; // "review-12" ou "comment-45"
  final String type; // 'review' | 'comment'
  final String authorId;
  final String authorName;
  final String text;
  final int? rating; // uniquement pour type == 'review'
  final String? parentId; // uniquement pour type == 'comment' (réponse à)
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isMine;

  ConversationMessage({
    required this.id,
    required this.type,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.rating,
    required this.parentId,
    required this.createdAt,
    required this.updatedAt,
    required this.isMine,
  });

  bool get isReview => type == 'review';

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(
      id: json['id'] as String,
      type: json['type'] as String,
      authorId: json['author_id'] as String,
      authorName: json['author_name'] as String? ?? '',
      text: json['text'] as String? ?? '',
      rating: json['rating'] as int?,
      parentId: json['parent_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isMine: json['is_mine'] as bool? ?? false,
    );
  }
}
