import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/publication_service.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showFavoritesOnly = false;
  final Set<int> _togglingFavorites = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite(int categoryId) async {
    if (_togglingFavorites.contains(categoryId)) return;
    setState(() => _togglingFavorites.add(categoryId));
    final service = ref.read(publicationServiceProvider);
    try {
      await service.toggleCategoryFavorite(categoryId);
      if (!mounted) return;
      ref.refresh(categoriesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Impossible de mettre à jour le favori : $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _togglingFavorites.remove(categoryId));
      }
    }
  }

  Widget _buildHeaderControls() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Parcourir les catégories',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Rechercher une catégorie',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Afficher uniquement les favoris',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Switch(
                  value: _showFavoritesOnly,
                  onChanged: (value) => setState(() {
                    _showFavoritesOnly = value;
                  }),
                  activeColor: Colors.orange.shade700,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Appuyez sur le cœur pour ajouter ou retirer une catégorie de vos favoris.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final currentUser = ref.watch(authServiceProvider).currentUser;
    final isPublisher = currentUser?.isPublisher == true;
    final isAdmin = currentUser?.isAdmin == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(isPublisher: isPublisher, isAdmin: isAdmin),
          if (!isPublisher && !isAdmin) _buildHeaderControls(),
          if (isPublisher)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRoleCard(
                      icon: Icons.edit_note_rounded,
                      title: 'Centre d’outils éditeur',
                      subtitle:
                          'Gérez vos contenus, vos publications et vos performances.',
                      actions: [
                        _buildActionTile(
                          context,
                          icon: Icons.create_outlined,
                          title: 'Créer un article',
                          subtitle: 'Publiez votre contenu rapidement.',
                          route: '/poster/create-article',
                        ),
                        _buildActionTile(
                          context,
                          icon: Icons.article_outlined,
                          title: 'Mes articles',
                          subtitle: 'Consultez et gérez vos publications.',
                          route: '/poster/my-articles',
                        ),
                        _buildActionTile(
                          context,
                          icon: Icons.insights_outlined,
                          title: 'Statistiques',
                          subtitle: 'Analysez votre audience et vos ventes.',
                          route: '/poster/statistics',
                        ),
                        _buildActionTile(
                          context,
                          icon: Icons.card_membership_outlined,
                          title: 'Plans & abonnements',
                          subtitle: 'Configurez vos offres et accès.',
                          route: '/poster/plans',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else if (isAdmin)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRoleCard(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Centre d’administration',
                      subtitle:
                          'Pilotez les modules de supervision et de modération.',
                      actions: [
                        _buildActionTile(
                          context,
                          icon: Icons.group_outlined,
                          title: 'Utilisateurs',
                          subtitle: 'Gérez les comptes et leurs statuts.',
                          route: '/admin/manage-users',
                        ),
                        _buildActionTile(
                          context,
                          icon: Icons.rate_review_outlined,
                          title: 'Avis & modération',
                          subtitle:
                              'Surveillez les signalements et commentaires.',
                          route: '/admin/manage-reviews',
                        ),
                        _buildActionTile(
                          context,
                          icon: Icons.bar_chart_outlined,
                          title: 'Statistiques',
                          subtitle: 'Suivez les performances de la plateforme.',
                          route: '/admin/statistics',
                        ),
                        _buildActionTile(
                          context,
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'Comptabilité',
                          subtitle: 'Analysez les transactions et soldes.',
                          route: '/admin/comptabilite',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            categoriesAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
              error: (error, stack) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'Erreur: ${error.toString()}',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              data: (categories) {
                if (isPublisher) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.tune_rounded,
                                        color: Colors.orange.shade800),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Sélection de catégorie',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Pour chaque article, choisissez la catégorie directement depuis la page de création.',
                                  style:
                                      TextStyle(color: Colors.orange.shade900),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      context.go('/poster/create-article'),
                                  icon: const Icon(Icons.create_outlined),
                                  label: const Text('Créer un article'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Catégories disponibles pour vos articles',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: categories.map((category) {
                              return Chip(
                                label: Text(
                                    category['name']?.toString() ?? 'Sans nom'),
                                avatar: const Icon(Icons.category_rounded,
                                    size: 16),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (categories.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.folder_open_outlined,
                              size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text(
                            'Aucune catégorie créée',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  );
                }

                final filteredCategories = categories.where((category) {
                  final name =
                      (category['name']?.toString() ?? '').toLowerCase();
                  final query = _searchController.text.toLowerCase();
                  final matchesSearch = query.isEmpty || name.contains(query);
                  final matchesFavorite =
                      !_showFavoritesOnly || (category['is_favorite'] == true);
                  return matchesSearch && matchesFavorite;
                }).toList();

                if (filteredCategories.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            _showFavoritesOnly
                                ? Icons.favorite_border
                                : Icons.search_off_outlined,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _showFavoritesOnly
                                ? 'Aucune catégorie favorite'
                                : 'Aucune catégorie trouvée',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Utilisez la recherche ou basculez les favoris pour affiner la liste.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.05,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return _buildCategoryCard(
                          context, filteredCategories[index]);
                    }, childCount: filteredCategories.length),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar({required bool isPublisher, required bool isAdmin}) {
    final title = isPublisher
        ? 'Gestion éditeur'
        : isAdmin
            ? 'Gestion admin'
            : 'Catégories';

    return SliverAppBar(
      expandedHeight: 140.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF0A2647),
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
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
                right: -50,
                top: -50,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.04),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2C74B3).withOpacity(0.12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> actions,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.orange.shade700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...actions,
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go(route),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
      BuildContext context, Map<String, dynamic> category) {
    final colors = [
      const Color(0xFF2C74B3),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFF59E0B),
      const Color(0xFF06B6D4),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
      const Color(0xFFF97316),
    ];

    // Use category ID to pick a consistent color
    final categoryId = (category['id'] as int?) ?? 1;
    final colorIndex = categoryId.hashCode.toUnsigned(32) % colors.length;
    final color = colors[colorIndex];

    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Catégorie ${category['name'] ?? 'sans nom'} sélectionnée'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withOpacity(0.7)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.31),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Décoration en arrière-plan
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.10),
                ),
              ),
            ),
            Positioned(
              right: 16,
              top: 16,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => _toggleFavorite(categoryId),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: _togglingFavorites.contains(categoryId)
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            category['is_favorite'] == true
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: category['is_favorite'] == true
                                ? Colors.redAccent
                                : Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ),
            // Contenu
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_getCategoryIcon(category['name'] ?? ''),
                        color: Colors.white, size: 32),
                  ),
                  const Spacer(),
                  Text(
                    category['name'] ?? 'Sans nom',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${category['articles_count'] ?? 0} articles',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('actualit')) return Icons.newspaper_rounded;
    if (name.contains('sport')) return Icons.sports_soccer_rounded;
    if (name.contains('culture')) return Icons.theater_comedy_rounded;
    if (name.contains('econ') || name.contains('finance'))
      return Icons.trending_up_rounded;
    if (name.contains('tech')) return Icons.computer_rounded;
    if (name.contains('sant') || name.contains('health'))
      return Icons.favorite_rounded;
    if (name.contains('politique')) return Icons.gavel_rounded;
    if (name.contains('educat')) return Icons.school_rounded;
    return Icons.category_rounded;
  }
}
