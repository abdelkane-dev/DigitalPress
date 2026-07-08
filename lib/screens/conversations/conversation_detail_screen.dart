import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:digital_press/core/services/conversations_service.dart';
import 'package:digital_press/core/services/publication_service.dart';
import 'package:digital_press/core/services/auth_service.dart';

class ConversationDetailScreen extends ConsumerWidget {
  final int publicationId;

  const ConversationDetailScreen({super.key, required this.publicationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final publicationAsync =
        ref.watch(publicationDetailProvider(publicationId));
    final reviewsAsync = ref.watch(conversationReviewsProvider(publicationId));
    final currentUser = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discussion'),
        centerTitle: true,
      ),
      body: publicationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Erreur publication : $error')),
        data: (publication) {
          return reviewsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) =>
                Center(child: Text('Erreur commentaires : $error')),
            data: (reviews) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          publication.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (publication.categoryName != null &&
                            publication.categoryName!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              publication.categoryName!,
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Text(
                          'Discussion liée à cet article',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: reviews.isEmpty
                        ? Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                'Aucun commentaire trouvé pour cette publication.',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 15,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () async {
                              ref.refresh(
                                  conversationReviewsProvider(publicationId));
                              await ref.read(
                                  conversationReviewsProvider(publicationId)
                                      .future);
                            },
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: reviews.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final review = reviews[index];
                                final author =
                                    review['reader_username']?.toString() ??
                                        'Anonyme';
                                final comment =
                                    review['comment']?.toString() ?? '';
                                final rating =
                                    (review['rating'] as num?)?.toInt() ?? 0;
                                final createdAt =
                                    review['created_at']?.toString();
                                final isMine = currentUser != null &&
                                    author == currentUser.username;

                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            isMine ? 'Vous' : author,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (rating > 0)
                                            Row(
                                              children: List.generate(
                                                5,
                                                (i) => Icon(
                                                  i < rating
                                                      ? Icons.star
                                                      : Icons.star_border,
                                                  size: 14,
                                                  color: Colors.amber.shade700,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (createdAt != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            _formatDate(createdAt),
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      if (comment.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 12),
                                          child: Text(
                                            comment,
                                            style: const TextStyle(
                                                fontSize: 15, height: 1.5),
                                          ),
                                        ),
                                      if (comment.isEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 12),
                                          child: Text(
                                            'Aucun texte soumis.',
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 14,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(String isoDate) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return isoDate;
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Aujourd’hui';
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
    return '${date.day}/${date.month}/${date.year}';
  }
}
