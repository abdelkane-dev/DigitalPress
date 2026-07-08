class Bookmark {
  final String id;
  final String journalId;
  final String userId;
  final DateTime bookmarkedAt;
  final String? note;

  Bookmark({
    required this.id,
    required this.journalId,
    required this.userId,
    required this.bookmarkedAt,
    this.note,
  });

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      id: json['id'] as String,
      journalId: json['journal_id'] as String,
      userId: json['user_id'] as String,
      bookmarkedAt: DateTime.parse(json['bookmarked_at'] as String),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'journal_id': journalId,
      'user_id': userId,
      'bookmarked_at': bookmarkedAt.toIso8601String(),
      'note': note,
    };
  }

  Bookmark copyWith({
    String? id,
    String? journalId,
    String? userId,
    DateTime? bookmarkedAt,
    String? note,
  }) {
    return Bookmark(
      id: id ?? this.id,
      journalId: journalId ?? this.journalId,
      userId: userId ?? this.userId,
      bookmarkedAt: bookmarkedAt ?? this.bookmarkedAt,
      note: note ?? this.note,
    );
  }
}
