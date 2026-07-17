import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/publication_service.dart';
import 'edit_article_screen.dart';
import 'article_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MyArticlesScreen extends ConsumerWidget {
  const MyArticlesScreen({super.key});

  String _formatDate(DateTime? date) {
    if (date == null) return '--/--/----';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articlesState = ref.watch(publisherPublicationsListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Mes articles'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref
                .read(publisherPublicationsListProvider.notifier)
                .loadMyPublications(),
          )
        ],
      ),
      body: articlesState.when(
        data: (articles) {
          if (articles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.article_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucun article rédigé',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A2647)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Commencez à rédiger vos articles pour\nles proposer à vos lecteurs.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: articles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final article = articles[index];

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0A2647).withAlpha(8),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// COVER IMAGE
                    if (article.coverImage.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: article.coverImage,
                          height: 170,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 170,
                            width: double.infinity,
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) {
                            return Container(
                              height: 120,
                              width: double.infinity,
                              color: Colors.grey.shade100,
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 42,
                                color: Colors.grey.shade500,
                              ),
                            );
                          },
                        ),
                      )
                    else
                      Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                        ),
                        child: Icon(
                          Icons.article_outlined,
                          size: 42,
                          color: Colors.grey.shade500,
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            /// TITLE + STATUS
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    article.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: article.status == 'published'
                                        ? Colors.green.shade50
                                        : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    article.status == 'published'
                                        ? 'Publié'
                                        : 'Brouillon',
                                    style: TextStyle(
                                      color: article.status == 'published'
                                          ? Colors.green.shade700
                                          : Colors.orange.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            /// META DATA
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                _MetaChip(
                                  icon: Icons.category_outlined,
                                  label: article.categoryName ?? 'Actualités',
                                ),
                                _MetaChip(
                                  icon: Icons.visibility_outlined,
                                  label: '${article.viewsCount}',
                                ),
                                _MetaChip(
                                  icon: Icons.calendar_today_outlined,
                                  label: _formatDate(article.createdAt),
                                ),
                                if (article.prix > 0)
                                  _MetaChip(
                                    icon: Icons.payments_outlined,
                                    label:
                                        '${article.prix.toStringAsFixed(0)}FCFA',
                                  )
                                else
                                  const _MetaChip(
                                    icon: Icons.money_off_rounded,
                                    label: 'Gratuit',
                                  ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            /// SUMMARY
                            Text(
                              article.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),

                            const SizedBox(height: 10),

                            /// ACTION BUTTONS (Compact)
                            SizedBox(
                              height: 36,
                              child: Row(
                                spacing: 6,
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.visibility,
                                          size: 16),
                                      label: const Text('Voir',
                                          style: TextStyle(fontSize: 11)),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ArticleDetailScreen(
                                                publication: article),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text('Modifier',
                                          style: TextStyle(fontSize: 11)),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => EditArticleScreen(
                                                publication: article),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: Icon(
                                        article.status == 'published'
                                            ? Icons.unpublished
                                            : Icons.publish,
                                        size: 16,
                                      ),
                                      label: Text(
                                        article.status == 'published'
                                            ? 'Brouillon'
                                            : 'Publier',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      onPressed: () async {
                                        try {
                                          await ref
                                              .read(
                                                  publisherPublicationsListProvider
                                                      .notifier)
                                              .toggleStatus(
                                                  article.id, article.status);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  article.status == 'published'
                                                      ? 'Retiré des publications'
                                                      : 'Publié !',
                                                ),
                                                backgroundColor: Colors.green,
                                                duration:
                                                    const Duration(seconds: 1),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text('Erreur : $e'),
                                                backgroundColor: Colors.red,
                                                duration:
                                                    const Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.orange)),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erreur : $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref
                    .read(publisherPublicationsListProvider.notifier)
                    .loadMyPublications(),
                child: const Text('Réessayer'),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
