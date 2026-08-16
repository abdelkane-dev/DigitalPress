import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    final displayName = (user?.displayName?.isNotEmpty ?? false)
        ? user!.displayName!
        : (user?.username.isNotEmpty ?? false)
            ? user!.username
            : 'Admin';
    final cards = [
      _AdminCardData(
        title: 'Statistiques globales',
        subtitle: 'Voir les performances générales des éditeurs',
        icon: Icons.bar_chart,
        route: '/admin/statistics',
      ),
      _AdminCardData(
        title: 'Créer un éditeur',
        subtitle: 'Ajouter un nouveau compte éditeur vérifié',
        icon: Icons.person_add_alt_1,
        route: '/admin/create-poster',
      ),
      _AdminCardData(
        title: 'Vérifications éditeurs',
        subtitle: "Valider ou rejeter les dossiers de légitimité (sous 24h)",
        icon: Icons.fact_check_outlined,
        route: '/admin/verifications',
      ),
      _AdminCardData(
        title: 'Gestion des catégories',
        subtitle: 'Créer, renommer ou supprimer les catégories de publications',
        icon: Icons.category_rounded,
        route: '/admin/categories',
      ),
      _AdminCardData(
        title: 'Gérer les éditeurs',
        subtitle: 'Voir, avertir, bannir ou débannir',
        icon: Icons.manage_accounts,
        route: '/admin/manage-posters',
      ),
      _AdminCardData(
        title: 'Gérer les utilisateurs',
        subtitle: 'Tous les comptes : lecteurs, éditeurs, admins',
        icon: Icons.people_alt_outlined,
        route: '/admin/manage-users',
      ),
      _AdminCardData(
        title: 'Modération des avis',
        subtitle: 'Consulter et supprimer les avis inappropriés',
        icon: Icons.reviews_outlined,
        route: '/admin/manage-reviews',
      ),
      _AdminCardData(
        title: 'Mises en avant (À LA UNE)',
        subtitle: 'Voir les promotions payantes, revenu et annulations',
        icon: Icons.star_rounded,
        route: '/admin/featured',
      ),
      _AdminCardData(
        title: 'Comptabilité',
        subtitle: 'Vue financière globale de la plateforme',
        icon: Icons.account_balance_outlined,
        route: '/admin/comptabilite',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/app_icon.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Admin Dashboard'),
          ],
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bienvenue, $displayName',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Gérez les éditeurs, suivez leur activité et supervisez la plateforme.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/app_icon.png',
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: cards.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final card = cards[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: card.route.isEmpty
                        ? null
                        : () => context.push(card.route),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white,
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 10,
                            color: Colors.black12,
                            offset: Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.blue.shade100,
                            child: Icon(card.icon, color: Colors.blue.shade700),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  card.title,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  card.subtitle,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminCardData {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;

  _AdminCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });
}