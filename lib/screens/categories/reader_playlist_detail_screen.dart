import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/favorites_service.dart';
import '../../model/favorite_article.dart';

/// Contenu d'une playlist (catégorie personnelle) du Lecteur : les articles
/// qu'il a mis en favoris et rangés dans cette catégorie, façon playlist
/// YouTube.
class ReaderPlaylistDetailScreen extends ConsumerWidget {
  final int categoryId;
  final String categoryName;

  const ReaderPlaylistDetailScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  Future<void> _removeFromPlaylist(WidgetRef ref, FavoriteArticle article) async {
    final remainingCategoryIds =
        article.categoryIds.where((id) => id != categoryId).toList();
    await ref.read(favoritesServiceProvider).addOrUpdateFavorite(
          article.id,
          categoryIds: remainingCategoryIds,
        );
    ref.invalidate(favoritesProvider(categoryId));
    ref.invalidate(favoritesProvider(null));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesProvider(categoryId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(categoryName),
        centerTitle: true,
      ),
      body: favoritesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (articles) {
          if (articles.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.playlist_add_check_circle_outlined,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text(
                      'Cette playlist est vide',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ajoutez des articles à vos favoris depuis leur page,\net rangez-les ici.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: articles.length,
            itemBuilder: (context, index) {
              final article = articles[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0A2647).withAlpha(10),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: article.coverImage.isNotEmpty
                        ? Image.network(
                            article.coverImage,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 56,
                              height: 56,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.article_outlined),
                            ),
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.article_outlined),
                          ),
                  ),
                  title: Text(
                    article.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  subtitle: Text(
                    article.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Retirer de cette playlist',
                    onPressed: () => _removeFromPlaylist(ref, article),
                  ),
                  onTap: () => context.push('/article/${article.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
