import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Modèle de favori
class BookmarkedJournal {
  final String id;
  final String title;
  final String category;
  final String imageUrl;
  final double price;
  final DateTime bookmarkedAt;

  BookmarkedJournal({
    required this.id,
    required this.title,
    required this.category,
    required this.imageUrl,
    required this.price,
    required this.bookmarkedAt,
  });
}

// Provider pour les favoris
final bookmarksProvider = StateProvider<List<BookmarkedJournal>>((ref) {
  return [
    BookmarkedJournal(
      id: '1',
      title: 'L\'Essor - Édition Spéciale',
      category: 'Actualités',
      imageUrl: 'https://via.placeholder.com/150',
      price: 500,
      bookmarkedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    BookmarkedJournal(
      id: '2',
      title: 'Jeune Afrique',
      category: 'Culture',
      imageUrl: 'https://via.placeholder.com/150',
      price: 1500,
      bookmarkedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];
});

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarksProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(bookmarks.length),
          if (bookmarks.isEmpty)
            _buildEmptyState()
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  return _buildBookmarkCard(context, ref, bookmarks[index]);
                }, childCount: bookmarks.length),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar(int count) {
    return SliverAppBar(
      expandedHeight: 140.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF0A2647),
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Mes Conversations',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C74B3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A2647), Color(0xFF144272)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -40,
                top: -40,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bookmark_outline_rounded,
                size: 80,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucune conversation',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vous n\'avez commenté aucun article récemment',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookmarkCard(
    BuildContext context,
    WidgetRef ref,
    BookmarkedJournal bookmark,
  ) {
    return Dismissible(
      key: Key(bookmark.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_remove_rounded, color: Colors.white, size: 32),
            SizedBox(height: 4),
            Text(
              'Retirer',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (direction) {
        final bookmarks = ref.read(bookmarksProvider);
        ref.read(bookmarksProvider.notifier).state =
            bookmarks.where((b) => b.id != bookmark.id).toList();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Conversation masquée'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            action: SnackBarAction(
              label: 'Annuler',
              onPressed: () {},
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A2647).withAlpha(8),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              Image.network(
                bookmark.imageUrl,
                width: 100,
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 100,
                    height: 140,
                    color: Colors.grey.shade200,
                    child: Icon(
                      Icons.image_not_supported_rounded,
                      color: Colors.grey.shade400,
                    ),
                  );
                },
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C74B3).withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          bookmark.category.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF2C74B3),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        bookmark.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0A2647),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(bookmark.bookmarkedAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${bookmark.price.toStringAsFixed(0)} FCFA',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2C74B3),
                            ),
                          ),
                          const Icon(
                            Icons.bookmark_rounded,
                            color: Color(0xFF2C74B3),
                            size: 24,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Aujourd\'hui';
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} jours';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
