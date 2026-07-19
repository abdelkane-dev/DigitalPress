import 'dart:ui';
import 'package:digital_press/widgets/subscribe_or_buy_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/auth_service.dart';
import '../categories/categories_screen.dart';
import '../conversations/conversations_screen.dart';
import '../roadmap/feature_roadmap_screen.dart';
import '../profile/profile_screen.dart';
import 'package:go_router/go_router.dart';
import '../../model/publication.dart';
import '../../core/services/publication_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/main_app_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  String _selectedCategory = 'Tous';
  int? _selectedPublisherId;
  final TextEditingController _searchController = TextEditingController();
  bool _isGridView = true;

  final List<String> _categories = [
    'Tous',
    'Actualités',
    'Sports',
    'Culture',
    'Économie',
    'Tech',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(publicationListProvider.notifier).load(
            refresh: true,
            publisherId: _selectedPublisherId,
          );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  /// Admin et Éditeur n'ont plus de sens à voir la page "Catégories" (page
  /// réservée au Lecteur) : elle est remplacée, pour ces deux rôles, par la
  /// page "Fonctionnalités à venir" (fonctionnalités pas encore
  /// implémentées mais utiles, à suivre/proposer).
  bool _secondTabIsFeatureRoadmap(WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    return user != null && (user.isAdmin || user.isPublisher);
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _secondTabIsFeatureRoadmap(ref)
            ? const FeatureRoadmapScreen()
            : _buildCategoriesTab();
      case 2:
        return _buildConversationsTab();
      case 3:
        return _buildProfileTab();
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    final pubState = ref.watch(publicationListProvider);
    final items = pubState.items;

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(publicationListProvider.notifier).load(
              refresh: true,
              search: _searchController.text.isEmpty
                  ? null
                  : _searchController.text,
              category: _selectedCategory == 'Tous' ? null : _selectedCategory,
              publisherId: _selectedPublisherId,
            );
      },
      child: CustomScrollView(
        slivers: [
          MainAppBar(
            title: 'DigitalPress',
            showLogo: true,
            extraAction: Container(
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                icon: Icon(
                  _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                  color: const Color(0xFF0A2647),
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isGridView = !_isGridView;
                  });
                },
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildSearchBar()),
          SliverToBoxAdapter(child: _buildRoleAccessButton(ref)),
          SliverToBoxAdapter(child: _buildCategoryChips()),
          if (pubState.isLoading && items.isEmpty)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            )
          else if (pubState.error != null && items.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Text('Erreur : ${pubState.error}'),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: _isGridView
                  ? _buildJournalGrid(items)
                  : _buildJournalList(items),
            ),
          if (pubState.isLoading && items.isNotEmpty)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoleAccessButton(WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;

    if (user == null) return const SizedBox.shrink();

    // ADMIN BUTTON
    if (user.isAdmin) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => context.push('/admin'),
            icon: const Icon(Icons.admin_panel_settings),
            label: const Text('Accéder à l’espace Admin'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      );
    }

    // ÉDITEUR
    if (user.isPublisher) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => context.push('/poster'),
            icon: const Icon(Icons.edit_note),
            label: const Text('Accéder à l’espace Éditeur'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      );
    }

    // CLIENT = NO BUTTON
    return const SizedBox.shrink();
  }



  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          hintText: 'Rechercher un journal...',
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF336B82),
            size: 24,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: Colors.grey.shade400),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                    });
                    ref.read(publicationListProvider.notifier).load(
                          refresh: true,
                          category: _selectedCategory == 'Tous'
                              ? null
                              : _selectedCategory,
                        );
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        onChanged: (value) {
          setState(() {});
          ref.read(publicationListProvider.notifier).load(
                refresh: true,
                category:
                    _selectedCategory == 'Tous' ? null : _selectedCategory,
                search: value.isEmpty ? null : value,
              );
        },
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(
                category,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              backgroundColor: Colors.grey.shade200,
              selectedColor: const Color(0xFF336B82),
              checkmarkColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF336B82)
                      : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category;
                });
                ref.read(publicationListProvider.notifier).load(
                      refresh: true,
                      category: category == 'Tous' ? null : category,
                      search: _searchController.text.isEmpty
                          ? null
                          : _searchController.text,
                      publisherId: _selectedPublisherId,
                    );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildJournalGrid(List<Publication> items) {
    if (items.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text('Aucune publication trouvée'),
          ),
        ),
      );
    }
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        childAspectRatio: 0.70,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = items[index];
          return _buildModernJournalCard(
            publication: item,
            isNew: false,
          );
        },
        childCount: items.length,
      ),
    );
  }

  Widget _buildJournalList(List<Publication> items) {
    if (items.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text('Aucune publication trouvée'),
          ),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = items[index];
          return _buildListJournalCard(
            publication: item,
            isNew: false,
          );
        },
        childCount: items.length,
      ),
    );
  }

  Widget _buildModernJournalCard({
    required Publication publication,
    bool isNew = false,
  }) {
    final title = publication.title;
    final subtitle = publication.subtitle;
    final category = publication.categoryName ?? 'Actualités';
    final price = publication.prix;
    final imageUrl = publication.coverImage;

    return GestureDetector(
      onTap: () => showSubscribeOrBuySelection(context, ref, publication),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: Stack(
                      children: [
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          height: double.infinity,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) {
                            return Container(
                              color: Colors.grey.shade200,
                              child: Icon(
                                Icons.image_not_supported_rounded,
                                color: Colors.grey.shade400,
                                size: 40,
                              ),
                            );
                          },
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withAlpha(100),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isNew)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C74B3),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(30),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Text(
                          'NOUVEAU',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(230),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF0A2647),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                        letterSpacing: -0.3,
                      ),
                    ),
                  const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                        Text(
                          '${price.toStringAsFixed(0)} F',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF56B4E9),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C74B3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListJournalCard({
    required Publication publication,
    bool isNew = false,
  }) {
    final title = publication.title;
    final category = publication.categoryName ?? 'Actualités';
    final price = publication.prix;
    final imageUrl = publication.coverImage;
    return Container(
      height: 120,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Stack(
              children: [
                 CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 100,
                  height: 120,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 100,
                    height: 120,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) {
                    return Container(
                      width: 100,
                      height: 120,
                      color: Colors.grey.shade200,
                      child: Icon(
                        Icons.image_not_supported_rounded,
                        color: Colors.grey.shade400,
                      ),
                    );
                  },
                ),
                if (isNew)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C74B3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C74B3).withAlpha(25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            category.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF2C74B3),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${price.toStringAsFixed(0)} F',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF56B4E9),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              showSubscribeOrBuySelection(context, ref, publication),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A2647),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                          ),
                          child: const Text(
                            'LIRE',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
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
    );
  }

  Widget _buildCategoriesTab() {
    return const CategoriesScreen();
  }

  Widget _buildConversationsTab() {
    return const ConversationsScreen();
  }

  Widget _buildProfileTab() {
    return const ProfileScreen();
  }

  Widget _buildBottomNavigationBar() {
    final isAdminOrEditeur = _secondTabIsFeatureRoadmap(ref);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(
                    icon: Icons.roofing_outlined,
                    activeIcon: Icons.roofing_rounded,
                    label: 'Accueil',
                    index: 0,
                  ),
                  _buildNavItem(
                    icon: isAdminOrEditeur
                        ? Icons.rocket_launch_outlined
                        : Icons.dashboard_customize_outlined,
                    activeIcon: isAdminOrEditeur
                        ? Icons.rocket_launch_rounded
                        : Icons.dashboard_customize_rounded,
                    label: isAdminOrEditeur ? 'À venir' : 'Catégories',
                    index: 1,
                  ),
                  _buildNavItem(
                    icon: Icons.mark_chat_unread_outlined,
                    activeIcon: Icons.mark_chat_unread_rounded,
                    label: 'Discussions',
                    index: 2,
                  ),
                  _buildNavItem(
                    icon: Icons.account_circle_outlined,
                    activeIcon: Icons.account_circle_rounded,
                    label: 'Profil',
                    index: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF336B82).withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: child,
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                key: ValueKey<bool>(isSelected),
                color: isSelected ? const Color(0xFF336B82) : Colors.grey.shade500,
                size: 26,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: isSelected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Color(0xFF336B82),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
