import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PosterDashboardScreen extends ConsumerWidget {
  const PosterDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = [
      _PosterCardData(
        title: 'Mes articles',
        subtitle: 'Voir et gérer mes publications',
        icon: Icons.article_outlined,
        route: '/poster/my-articles',
      ),
      _PosterCardData(
        title: 'Créer un article',
        subtitle: 'Rédiger un nouveau contenu',
        icon: Icons.edit_note_outlined,
        route: '/poster/create-article',
      ),
      _PosterCardData(
        title: 'Mes statistiques',
        subtitle: 'Suivre les vues et performances',
        icon: Icons.bar_chart_outlined,
        route: '/poster/statistics',
      ),
      _PosterCardData(
        title: 'Avertissements reçus',
        subtitle: 'Consulter les motifs et l’historique',
        icon: Icons.warning_amber_rounded,
        route: '/poster/warnings',
      ),
      _PosterCardData(
        title: 'Mes plans d\'abonnement',
        subtitle: 'Créer et gérer les plans d\'abonnement',
        icon: Icons.star_rounded,
        route: '/poster/plans',
      ),
      _PosterCardData(
        title: 'Comptabilité',
        subtitle: 'Revenus, retraits et historique financier',
        icon: Icons.account_balance_wallet_outlined,
        route: '/poster/comptabilite',
      ),
      _PosterCardData(
        title: 'Mon profil éditeur',
        subtitle: 'Entreprise, coordonnées et informations publiques',
        icon: Icons.storefront_outlined,
        route: '/poster/profile',
      ),
      _PosterCardData(
        title: 'Fonctionnalités à venir',
        subtitle: 'Suivre et proposer les prochaines fonctionnalités',
        icon: Icons.construction_outlined,
        route: '/poster/feature-roadmap',
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
            const Text('Espace Éditeur'),
          ],
        ),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Bienvenue dans votre espace Éditeur',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Gérez vos publications et suivez vos performances.',
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
                    onTap: () => context.push(card.route),
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
                            radius: 26,
                            backgroundColor: Colors.orange.shade100,
                            child: Icon(
                              card.icon,
                              color: Colors.orange.shade700,
                            ),
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

                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 18,
                          ),
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

class _PosterCardData {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;

  _PosterCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });
}