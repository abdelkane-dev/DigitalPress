import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';

class PosterDashboardScreen extends ConsumerWidget {
  const PosterDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    // Priorité : nom de l'entreprise (raison sociale saisie par
    // l'éditeur) > nom personnel > nom d'utilisateur > repli générique.
    final displayName = (user?.companyName?.isNotEmpty ?? false)
        ? user!.companyName!
        : (user?.displayName?.isNotEmpty ?? false)
            ? user!.displayName!
            : (user?.username.isNotEmpty ?? false)
                ? user!.username
                : 'Éditeur';
    final cards = [
      _PosterCardData(
        title: 'Mes articles',
        subtitle: 'Gérer vos publications',
        icon: Icons.article_rounded,
        route: '/poster/my-articles',
        color: const Color(0xFFEA580C), // Orange 600
      ),
      _PosterCardData(
        title: 'Mon niveau',
        subtitle: 'Palier actuel et progression',
        icon: Icons.workspace_premium_rounded,
        route: '/poster/my-subscription',
        color: const Color(0xFFC2410C), // Orange 700
      ),
      _PosterCardData(
        title: 'Créer un article',
        subtitle: 'Rédiger un nouveau contenu',
        icon: Icons.edit_note_rounded,
        route: '/poster/create-article',
        color: const Color(0xFFF97316), // Orange 500
      ),
      _PosterCardData(
        title: 'Mes statistiques',
        subtitle: 'Suivre les vues et performances',
        icon: Icons.bar_chart_rounded,
        route: '/poster/statistics',
        color: const Color(0xFFD97706), // Amber 600
      ),
      _PosterCardData(
        title: 'Avertissements reçus',
        subtitle: 'Consulter l\'historique',
        icon: Icons.warning_amber_rounded,
        route: '/poster/warnings',
        color: const Color(0xFFDC2626), // Red 600
      ),
      _PosterCardData(
        title: 'Mes offres',
        subtitle: 'Plans d\'abonnement',
        icon: Icons.star_rounded,
        route: '/poster/plans',
        color: const Color(0xFFF59E0B), // Amber 500
      ),
      _PosterCardData(
        title: 'Comptabilité',
        subtitle: 'Revenus et retraits',
        icon: Icons.account_balance_wallet_rounded,
        route: '/poster/comptabilite',
        color: const Color(0xFFC2410C), // Orange 700
      ),
      _PosterCardData(
        title: 'Mon profil public',
        subtitle: 'Informations affichées aux lecteurs',
        icon: Icons.storefront_rounded,
        route: '/poster/profile',
        color: const Color(0xFFFB923C), // Orange 400
      ),
      _PosterCardData(
        title: 'Mes abonnés',
        subtitle: 'Lecteurs abonnés à vos offres',
        icon: Icons.people_alt_rounded,
        route: '/poster/subscribers',
        color: const Color(0xFFB45309), // Amber 700
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED), // Fond orange clair moderne
      appBar: AppBar(
        backgroundColor: const Color(0xFFEA580C), // Couleur orange
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Espace Éditeur',
          style: TextStyle(
            fontWeight: FontWeight.w900, 
            letterSpacing: -0.5,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Déterminer le nombre de colonnes (Responsive)
            int crossAxisCount = 1;
            if (constraints.maxWidth > 1024) {
              crossAxisCount = 3;
            } else if (constraints.maxWidth > 650) {
              crossAxisCount = 2;
            }

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                    child: _buildWelcomeBanner(displayName),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: constraints.maxWidth > 650 ? 1.5 : 1.3,
                      mainAxisExtent: 100, // Hauteur fixe pour chaque carte
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _buildDashboardCard(context, cards[index]);
                      },
                      childCount: cards.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(String displayName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8C00), Color(0xFFFF512F)], // Premium orange gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF512F).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bienvenue, $displayName !',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gérez vos publications, analysez vos statistiques et engagez vos lecteurs depuis votre espace professionnel.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context, _PosterCardData card) {
    return InkWell(
      onTap: () => context.push(card.route),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: card.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                card.icon,
                color: card.color,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    card.title,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade400,
              size: 24,
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
  final Color color;

  _PosterCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.color,
  });
}