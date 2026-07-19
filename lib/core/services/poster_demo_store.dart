import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../model/poster_article.dart';

final posterDemoStoreProvider =
    StateNotifierProvider<PosterDemoStore, List<PosterArticle>>((ref) {
  return PosterDemoStore();
});

class PosterDemoStore extends StateNotifier<List<PosterArticle>> {
  PosterDemoStore()
      : super([
          PosterArticle(
            id: 'a1',
            title: 'Les nouvelles tendances numériques au Mali',
            category: 'Technologie',
            summary: 'Un aperçu des évolutions digitales récentes.',
            content:
                '# Introduction\nLe numérique évolue rapidement au Mali.\n\n- Plus d’initiatives locales\n- Plus d’outils digitaux\n- Plus d’opportunités',
            status: 'published',
            views: 1240,
            createdAt: DateTime(2026, 3, 10),
          ),
          PosterArticle(
            id: 'a2',
            title: 'Événement sportif du week-end',
            category: 'Sports',
            summary: 'Résumé des matchs et temps forts.',
            content:
                '# Week-end sportif\nLes rencontres ont offert plusieurs temps forts.\n\n> Un article encore en cours de rédaction.',
            status: 'draft',
            views: 0,
            createdAt: DateTime(2026, 3, 12),
          ),
          PosterArticle(
            id: 'a3',
            title: 'Festival culturel à Bamako',
            category: 'Culture',
            summary: 'Retour sur les activités culturelles marquantes.',
            content:
                '# Festival culturel\nUne ambiance exceptionnelle a marqué cette édition.',
            status: 'published',
            views: 830,
            createdAt: DateTime(2026, 3, 13),
          ),
        ]);

  void addArticle({
    required String title,
    required String category,
    required String summary,
    required String content,
    required String status,
    String? coverImagePath,
  }) {
    final article = PosterArticle(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      category: category,
      summary: summary,
      content: content,
      status: status,
      views: 0,
      createdAt: DateTime.now(),
      coverImagePath: coverImagePath,
    );

    state = [article, ...state];
  }

  void updateArticle({
  required String id,
  required String title,
  required String category,
  required String summary,
  required String content,
  String? coverImagePath,
}) {
  state = state.map((article) {
    if (article.id != id) return article;

    return article.copyWith(
      title: title,
      category: category,
      summary: summary,
      content: content,
      coverImagePath: coverImagePath,
    );
  }).toList();
}

  void toggleStatus(String articleId) {
    state = state.map((article) {
      if (article.id != articleId) return article;

      return article.copyWith(
        status: article.status == 'draft' ? 'published' : 'draft',
      );
    }).toList();
  }

  void deleteArticle(String articleId) {
    state = state.where((article) => article.id != articleId).toList();
  }
}