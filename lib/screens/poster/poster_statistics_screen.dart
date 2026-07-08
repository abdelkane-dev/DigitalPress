import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/publication_service.dart';

class PosterStatisticsScreen extends ConsumerWidget {
  const PosterStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pubState = ref.watch(publisherPublicationsListProvider);
    final articles = pubState.valueOrNull ?? [];

    final totalArticles = articles.length;
    final published =
        articles.where((article) => article.status == 'published').length;
    final drafts = articles.where((article) => article.status == 'draft').length;
    final totalViews =
        articles.fold<int>(0, (sum, article) => sum + article.viewsCount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes statistiques'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _StatCard(
                title: 'Articles',
                value: '$totalArticles',
                icon: Icons.article,
              ),
              _StatCard(
                title: 'Publiés',
                value: '$published',
                icon: Icons.publish,
              ),
              _StatCard(
                title: 'Brouillons',
                value: '$drafts',
                icon: Icons.edit_document,
              ),
              _StatCard(
                title: 'Vues',
                value: '$totalViews',
                icon: Icons.visibility,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Performance par article',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...articles.map((article) {
            final maxViews = articles.isEmpty
                ? 1
                : articles
                    .map((e) => e.viewsCount)
                    .reduce((a, b) => a > b ? a : b)
                    .clamp(1, 999999);
            final ratio = article.viewsCount / maxViews;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 8,
                    color: Colors.black12,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${article.viewsCount} vues',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: ratio == 0 ? 0.02 : ratio.toDouble(),
                      minHeight: 10,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            color: Colors.black12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue.shade700),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}