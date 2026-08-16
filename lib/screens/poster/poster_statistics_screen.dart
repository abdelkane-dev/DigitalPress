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
    final drafts =
        articles.where((article) => article.status == 'draft').length;
    final totalViews =
        articles.fold<int>(0, (sum, article) => sum + article.viewsCount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes statistiques'),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;
          final crossAxisCount = isWide ? 2 : 2;
          final childAspectRatio = isWide ? 1.35 : 1.2;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: childAspectRatio,
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
                  'Historique des vues',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const _ViewsHistoryCard(),
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${article.viewsCount} vues',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
        },
      ),
    );
  }
}

/// Carte « Historique des vues » : graphique en barres des vues des
/// derniers jours (données du backend, PublicationView) + classement par
/// publication. Rechargée automatiquement via viewsHistoryProvider.
class _ViewsHistoryCard extends ConsumerWidget {
  const _ViewsHistoryCard();

  String _shortLabel(String isoDate) {
    final d = DateTime.tryParse(isoDate);
    if (d == null) return isoDate;
    return '${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(viewsHistoryProvider);

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: async.when(
        loading: () => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(Icons.bar_chart_rounded,
                  color: Colors.grey.shade400, size: 40),
              const SizedBox(height: 8),
              Text(
                'Pas encore de données de vues par jour.\nElles apparaîtront dès que vos articles seront lus.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
        data: (data) {
          final series = (data['series'] as List? ?? [])
              .whereType<Map<String, dynamic>>()
              .toList();
          if (series.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Pas encore de données de vues par jour.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            );
          }
          final maxCount = series.fold<int>(
              1, (m, e) => (e['count'] as num? ?? 0) > m ? (e['count'] as num).toInt() : m);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Graphique en barres (14 derniers jours) ────────────────
              SizedBox(
                height: 140,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final day in series)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${day['count']}',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: (day['count'] as num? ?? 0) > 0
                                      ? Colors.blue.shade700
                                      : Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                height: (day['count'] as num? ?? 0) == 0
                                    ? 3
                                    : 80 *
                                        ((day['count'] as num).toDouble() /
                                            maxCount),
                                decoration: BoxDecoration(
                                  color: (day['count'] as num? ?? 0) > 0
                                      ? Colors.blue.shade600
                                      : Colors.grey.shade300,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _shortLabel(day['date']?.toString() ?? ''),
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Classement des publications ────────────────────────────
              const Text(
                'Par publication',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...((data['per_publication'] as List? ?? [])
                  .whereType<Map<String, dynamic>>()
                  .take(5)
                  .map((p) {
                final total = (p['series'] as List? ?? []).fold<int>(
                    0,
                    (sum, e) =>
                        sum +
                        ((e is Map && e['count'] is num)
                            ? (e['count'] as num).toInt()
                            : 0));
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          p['title']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      Text(
                        '$total vues',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                );
              })),
            ],
          );
        },
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
          Icon(icon, color: Colors.blue.shade700, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
