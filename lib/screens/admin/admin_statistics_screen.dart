import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/admin_demo_store.dart';

class AdminStatisticsScreen extends ConsumerWidget {
  const AdminStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posters = ref.watch(adminDemoStoreProvider);

    final totalPosters = posters.length;
    final activePosters = posters.where((p) => !p.isBanned).length;
    final bannedPosters = posters.where((p) => p.isBanned).length;
    final totalWarnings = posters.fold<int>(0, (sum, p) => sum + p.warnings);
    final totalViews = posters.fold<int>(0, (sum, p) => sum + p.totalViews);
    final totalArticles =
        posters.fold<int>(0, (sum, p) => sum + p.totalArticles);
    final totalPublished =
        posters.fold<int>(0, (sum, p) => sum + p.publishedArticles);
    final totalDrafts =
        posters.fold<int>(0, (sum, p) => sum + p.draftArticles);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques globales'),
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
                title: 'Posters',
                value: '$totalPosters',
                icon: Icons.people,
              ),
              _StatCard(
                title: 'Actifs',
                value: '$activePosters',
                icon: Icons.verified_user,
              ),
              _StatCard(
                title: 'Bannis',
                value: '$bannedPosters',
                icon: Icons.block,
              ),
              _StatCard(
                title: 'Avertissements',
                value: '$totalWarnings',
                icon: Icons.warning_amber_rounded,
              ),
              _StatCard(
                title: 'Articles',
                value: '$totalArticles',
                icon: Icons.article,
              ),
              _StatCard(
                title: 'Publiés',
                value: '$totalPublished',
                icon: Icons.publish,
              ),
              _StatCard(
                title: 'Brouillons',
                value: '$totalDrafts',
                icon: Icons.edit_document,
              ),
              _StatCard(
                title: 'Vues totales',
                value: '$totalViews',
                icon: Icons.visibility,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 10,
                  color: Colors.black12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Résumé',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text('• Nombre total de posters : $totalPosters'),
                Text('• Posters actifs : $activePosters'),
                Text('• Posters bannis : $bannedPosters'),
                Text('• Avertissements cumulés : $totalWarnings'),
                Text('• Articles publiés : $totalPublished'),
                Text('• Articles en brouillon : $totalDrafts'),
                Text('• Total des vues : $totalViews'),
              ],
            ),
          ),
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