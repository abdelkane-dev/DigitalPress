/// Représente un article dans la page "Mes Conversations" : un élément par
/// article où l'utilisateur connecté a laissé au moins un commentaire.
class Conversation {
  final int articleId;
  final String title;
  final DateTime lastCommentDate;
  final int totalComments;
  final String lastCommentText;
  final String lastCommentAuthor;
  final String coverImage;
  final bool hasNewComments;
  final int newCommentsCount;

  Conversation({
    required this.articleId,
    required this.title,
    required this.lastCommentDate,
    required this.totalComments,
    required this.lastCommentText,
    required this.lastCommentAuthor,
    required this.coverImage,
    required this.hasNewComments,
    required this.newCommentsCount,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      articleId: json['id_article'] as int,
      title: json['titre_article'] as String? ?? '',
      lastCommentDate: DateTime.parse(json['date_dernier_commentaire'] as String),
      totalComments: json['nombre_total_commentaires'] as int? ?? 0,
      lastCommentText: json['texte_dernier_commentaire'] as String? ?? '',
      lastCommentAuthor: json['auteur_dernier_commentaire'] as String? ?? '',
      coverImage: json['cover_image'] as String? ?? '',
      hasNewComments: json['has_new_comments'] as bool? ?? false,
      newCommentsCount: json['nouveaux_commentaires_count'] as int? ?? 0,
    );
  }

  Conversation copyWith({
    bool? hasNewComments,
    int? newCommentsCount,
  }) {
    return Conversation(
      articleId: articleId,
      title: title,
      lastCommentDate: lastCommentDate,
      totalComments: totalComments,
      lastCommentText: lastCommentText,
      lastCommentAuthor: lastCommentAuthor,
      coverImage: coverImage,
      hasNewComments: hasNewComments ?? this.hasNewComments,
      newCommentsCount: newCommentsCount ?? this.newCommentsCount,
    );
  }
}
