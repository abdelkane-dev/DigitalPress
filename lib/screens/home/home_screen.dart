import 'dart:async';
import 'dart:ui';
import 'package:digital_press/widgets/subscribe_or_buy_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/auth_service.dart';
import '../categories/categories_screen.dart';
import '../conversations/conversations_screen.dart';
import '../poster/poster_subscribers_screen.dart';
import '../admin/admin_categories_screen.dart';
import '../profile/profile_screen.dart';
import 'package:go_router/go_router.dart';
import '../../model/publication.dart';
import '../../core/services/publication_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/short_video_player.dart';

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

  /// Anti-anti-rebond : la recherche n'appelle le backend que 350 ms après
  /// la dernière frappe, au lieu d'une requête par caractère tapé.
  Timer? _searchDebounce;

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
    _searchDebounce?.cancel();
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
  /// réservée au Lecteur) : remplacée par une vraie fonctionnalité propre à
  /// chaque rôle — "Mes abonnés" côté Éditeur, "Gestion des catégories"
  /// côté Admin (l'espace retrait éditeur a été supprimé de la plateforme).
  ///
  /// [embedded=true] : quand ces pages s'affichent dans les 4 onglets
  /// principaux, leur en-tête reprend celui des autres pages principales
  /// (logo + titre à gauche, icônes à droite). Sur leurs propres routes
  /// (/poster/subscribers, /admin/categories) elles gardent leur en-tête
  /// actuel — voir la demande explicite sur ce point.
  Widget? _secondTabRoleScreen(WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    if (user == null) return null;
    if (user.isAdmin) return const AdminCategoriesScreen(embedded: true);
    if (user.isPublisher) return const PosterSubscribersScreen(embedded: true);
    return null;
  }

  bool _isAdmin(WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    return user?.isAdmin ?? false;
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _secondTabRoleScreen(ref) ?? _buildCategoriesTab();
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
    // Vitrine « À la une » : mises en avant payantes/plan + tendances (fort
    // nombre de vues sur une courte période) — servies par le backend.
    final featuredAsync = ref.watch(featuredProvider);
    final featuredList = featuredAsync.valueOrNull?['featured'] ?? [];
    final trendingList = featuredAsync.valueOrNull?['trending'] ?? [];

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(featuredProvider);
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
          // ─── EN-TÊTE ACCUEIL (agrandi) ───────────────────────────────
          // Logo + « DigitalPress » collés à gauche et mis en avant, les 3
          // icônes (grille/liste, cloche, avatar) sur la même ligne collées
          // à droite et plus petites, puis le message de bienvenue / bon
          // retour sur la ligne suivante (uniquement sur l'accueil).
          MainAppBar(
            title: 'DigitalPress',
            showLogo: true,
            showWelcome: true,
            enlarged: true,
            extraAction: Container(
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                icon: Icon(
                  _isGridView
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                  color: const Color(0xFF0A2647),
                  size: 18,
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
          // Section « À la une » : publications mises en avant (payantes ou
          // plan) — repli sur les plus récentes si aucune n'est marquée.
          SliverToBoxAdapter(
            child: _buildFeaturedSection(
              items,
              featuredList: featuredList,
            ),
          ),
          // Section « Tendances » : publications à fort nombre de vues sur
          // une courte période (nombre impressionnant de vues en peu de
          // temps) — calculé côté backend sur les 48 dernières heures.
          if (trendingList.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildTrendingSection(trendingList),
            ),
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
          // ─── CORRECTIF : espace en bas pour que toutes les cartes soient
          // entièrement visibles en scrollant jusqu'en bas (la barre de
          // navigation flottante ne masque plus les dernières cartes).
          const SliverToBoxAdapter(child: SizedBox(height: 140)),
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
            onPressed: () async {
              await context.push('/admin');
              if (mounted) {
                ref.read(publicationListProvider.notifier).load(refresh: true);
              }
            },
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
            onPressed: () async {
              await context.push('/poster');
              if (mounted) {
                ref.read(publicationListProvider.notifier).load(refresh: true);
              }
            },
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
                    // Annule toute recherche en attente puis recharge sans filtre.
                    _searchDebounce?.cancel();
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
          // Debounce : on attend que l'utilisateur arrête de taper avant de
          // lancer la requête (économie de requêtes + évite les courses).
          _searchDebounce?.cancel();
          _searchDebounce = Timer(const Duration(milliseconds: 350), () {
            if (!mounted) return;
            ref.read(publicationListProvider.notifier).load(
                  refresh: true,
                  category:
                      _selectedCategory == 'Tous' ? null : _selectedCategory,
                  search: value.isEmpty ? null : value,
                );
          });
        },
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categoriesAsync = ref.watch(categoriesProvider);
    final dynamicCategories = categoriesAsync.maybeWhen(
      data: (cats) {
        final names = cats
            .map((c) => (c['name'] ?? '').toString().trim())
            .where((s) => s.isNotEmpty)
            .toList();
        return ['Tous', ...names];
      },
      orElse: () => _categories,
    );
    final categories = dynamicCategories.toSet().toList();
    if (!categories.contains('Tous')) categories.insert(0, 'Tous');

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
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
                        _buildPublicationCover(publication,
                            height: double.infinity, width: double.infinity),
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
                  // Badge du type de publication (Article, Magazine…)
                  Positioned(
                    bottom: 8,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C74B3).withAlpha(220),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _publicationTypeIcon(publication),
                            size: 10,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _publicationTypeLabel(publication),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
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
                        price > 0 ? '${price.toStringAsFixed(0)} F' : 'gratuit',
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
                _buildPublicationCover(publication, width: 100, height: 120),
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
                          price > 0 ? '${price.toStringAsFixed(0)} F' : 'gratuit',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF56B4E9),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => showSubscribeOrBuySelection(
                              context, ref, publication),
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

  /// Carrousel « À la une » : grandes cartes dégradées sur l'image de
  /// couverture. Alimenté par l'endpoint dédié (mises en avant payantes ou
  /// plan), avec repli sur les publications marquées is_featured puis sur
  /// les plus récentes si la vitrine est vide. La vitrine peut contenir
  /// jusqu'à 12 publications (demande explicite).
  Widget _buildFeaturedSection(
    List<Publication> items, {
    required List<Publication> featuredList,
  }) {
    if (items.isEmpty && featuredList.isEmpty) return const SizedBox.shrink();
    final fromEndpoint = featuredList.where((p) => p.isFeatured).toList();
    const maxFeatured = 12;
    final carousel = fromEndpoint.isNotEmpty
        ? fromEndpoint.take(maxFeatured).toList()
        : (items.where((p) => p.isFeatured).take(maxFeatured).isNotEmpty
            ? items.where((p) => p.isFeatured).take(maxFeatured).toList()
            : items.take(maxFeatured).toList());
    if (carousel.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFB45309), size: 20),
              const SizedBox(width: 6),
              Text(
                'À LA UNE',
                style: TextStyle(
                  color: const Color(0xFFB45309),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            itemCount: carousel.length,
            itemBuilder: (context, index) {
              final pub = carousel[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildFeaturedCard(pub),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Section « Tendances » : publications qui explosent en vues sur une
  /// courte période, présentées en cartes horizontales.
  Widget _buildTrendingSection(List<Publication> trending) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: Color(0xFFE8590C), size: 20),
              const SizedBox(width: 6),
              Text(
                'TENDANCES 🔥',
                style: TextStyle(
                  color: const Color(0xFFE8590C),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            itemCount: trending.length,
            itemBuilder: (context, index) {
              final pub = trending[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildTrendingCard(pub),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrendingCard(Publication pub) {
    return GestureDetector(
      onTap: () => showSubscribeOrBuySelection(context, ref, pub),
      child: Container(
        width: 240,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 84,
              height: 130,
              child: _buildPublicationCover(pub, width: 84, height: 130),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      pub.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.visibility_outlined,
                                size: 12, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text('${pub.viewsCount} vues',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          pub.prix > 0
                              ? '${pub.prix.toStringAsFixed(0)} F'
                              : 'gratuit',
                          style: const TextStyle(
                            color: Color(0xFF56B4E9),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
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

  Widget _buildFeaturedCard(Publication pub) {
    final category = pub.categoryName ?? 'Actualités';
    return GestureDetector(
      onTap: () => showSubscribeOrBuySelection(context, ref, pub),
      child: Container(
        width: 300,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildPublicationCover(pub,
                width: double.infinity, height: double.infinity),
            // Voile dégradé navy → transparent pour la lisibilité du texte.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xB30A2647)],
                ),
              ),
            ),
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(235),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  category.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF0A2647),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pub.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.visibility_outlined,
                          color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text('${pub.viewsCount} vues',
                          style:
                              const TextStyle(color: Colors.white70, fontSize: 11)),
                      const Spacer(),
                      Text(
                        pub.prix > 0
                            ? '${pub.prix.toStringAsFixed(0)} F'
                            : 'gratuit',
                        style: const TextStyle(
                          color: Color(0xFF56B4E9),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
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

  /// Petit libellé du type de publication (Article, Magazine, Journal,
  /// Rapport, E-book) — chaque type est identifiable dès la liste.
  String _publicationTypeLabel(Publication pub) {
    switch (pub.pubType) {
      case 'magazine':
        return 'MAGAZINE';
      case 'journal':
        return 'JOURNAL';
      case 'report':
        return 'RAPPORT';
      case 'ebook':
        return 'E-BOOK';
      default:
        return 'ARTICLE';
    }
  }

  IconData _publicationTypeIcon(Publication pub) {
    switch (pub.pubType) {
      case 'magazine':
        return Icons.auto_stories_rounded;
      case 'journal':
        return Icons.newspaper_rounded;
      case 'report':
        return Icons.insert_drive_file_rounded;
      case 'ebook':
        return Icons.menu_book_rounded;
      default:
        return Icons.article_rounded;
    }
  }

  Widget _buildPublicationCover(Publication publication,
      {double? width, double? height}) {
    if (publication.videoUrl.isNotEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          // Vidéo de couverture : se joue automatiquement UNE seule fois à
          // l'affichage, puis la lecture passe sous le contrôle du lecteur.
          child: ShortVideoPlayer(
            videoUrl: publication.videoUrl,
            title: publication.title,
            autoPlayOnce: true,
          ),
        ),
      );
    }
    // Couverture image ou, à défaut, un fond dégradé avec l'icône du type
    // (une publication sans aucune couverture ne doit plus jamais apparaître
    // en blanc / image cassée).
    final hasImage = publication.coverImage.isNotEmpty;
    return SizedBox(
      width: width,
      height: height,
      child: hasImage
          ? CachedNetworkImage(
              imageUrl: publication.coverImage,
              width: width,
              height: height,
              fit: BoxFit.cover,
              // Placeholder : même dégradé que le fallback (jamais un carré
              // gris « cassé » pendant le chargement) + petit spinner discret.
              placeholder: (context, url) => Stack(
                fit: StackFit.expand,
                children: [
                  _buildCoverFallback(publication, width, height),
                  const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                ],
              ),
              errorWidget: (context, url, error) =>
                  _buildCoverFallback(publication, width, height),
            )
          : _buildCoverFallback(publication, width, height),
    );
  }

  /// Fond dégradé avec l'icône du type de publication — utilisé quand la
  /// publication n'a ni image ni vidéo de couverture (ou que l'image est
  /// cassée), pour ne jamais afficher un carré blanc ou une image cassée.
  Widget _buildCoverFallback(Publication publication, double? width, double? height) {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A2647), Color(0xFF2C74B3)],
        ),
      ),
      child: Center(
        child: Icon(
          _publicationTypeIcon(publication),
          color: Colors.white70,
          size: 36,
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
    final isAdminOrEditeur = _secondTabRoleScreen(ref) != null;
    final isAdmin = _isAdmin(ref);

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
                        ? (isAdmin
                            ? Icons.category_outlined
                            : Icons.people_alt_outlined)
                        : Icons.dashboard_customize_outlined,
                    activeIcon: isAdminOrEditeur
                        ? (isAdmin
                            ? Icons.category_rounded
                            : Icons.people_alt_rounded)
                        : Icons.dashboard_customize_rounded,
                    label: isAdminOrEditeur
                        ? (isAdmin ? 'Catégories' : 'Abonnés')
                        : 'Catégories',
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
        // Plus aucun rechargement automatique au tap sur Accueil : le fil
        // se met à jour en temps réel (WebSocket) et au tirage vers le bas
        // (demande explicite : "pas de chargement/actualisation à chaque
        // action, ça doit fonctionner comme WhatsApp").
        // L'onglet Profil du pied de page reste un onglet NORMAL : il ouvre
        // la page profil comme avant (le menu d'actions rapides, lui, est
        // réservé à l'avatar de l'en-tête — demande explicite).
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
                color:
                    isSelected ? const Color(0xFF336B82) : Colors.grey.shade500,
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
