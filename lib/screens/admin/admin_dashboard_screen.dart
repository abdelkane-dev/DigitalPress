import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _AdminCardData(
        title: 'Statistiques globales',
        subtitle: 'Voir les performances générales des posters',
        icon: Icons.bar_chart,
        route: '/admin/statistics',
      ),
      _AdminCardData(
        title: 'Créer un poster',
        subtitle: 'Ajouter un nouveau compte poster vérifié',
        icon: Icons.person_add_alt_1,
        route: '/admin/create-poster',
      ),
      _AdminCardData(
        title: 'Gérer les posters',
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
        title: 'Gérer les catégories',
        subtitle: 'Créer, modifier ou supprimer des catégories',
        icon: Icons.category_outlined,
        route: '/admin/manage-categories',
      ),
      _AdminCardData(
        title: 'Modération des avis',
        subtitle: 'Consulter et supprimer les avis inappropriés',
        icon: Icons.reviews_outlined,
        route: '/admin/manage-reviews',
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
        title: const Text('Admin Dashboard'),
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
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bienvenue, Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Gérez les posters, suivez leur activité et supervisez la plateforme.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
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