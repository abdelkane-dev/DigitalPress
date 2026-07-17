import 'dart:io';
import 'package:digital_press/widgets/subscribe_or_buy_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/auth_service.dart';
import '../notifications/notifications_screen.dart';
import '../../widgets/notification_bell_button.dart';
import '../categories/categories_screen.dart';
import '../conversations/conversations_screen.dart';
import '../roadmap/feature_roadmap_screen.dart';
import '../profile/profile_screen.dart';
import 'package:go_router/go_router.dart';
import '../../model/publication.dart';
import '../../core/services/publication_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
      backgroundColor: const Color(0xFFF8FAFC),
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
          _buildModernAppBar(),
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

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 150.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF0A2647),
      flexibleSpace: FlexibleSpaceBar(
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
              // Cercles décoratifs
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(10),
                  ),
                ),
              ),
              Positioned(
                left: -20,
                bottom: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2C74B3).withAlpha(30),
                  ),
                ),
              ),
              // Logo + "DigitalPress" — en haut à gauche, même colonne que la photo
              Positioned(
                left: 20,
                top: 52,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/app_icon.png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'DigitalPress',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Photo de profil + nom utilisateur — en bas à gauche
              Positioned(
                left: 20,
                bottom: 12,
                child: Consumer(
                  builder: (context, ref, child) {
                    final user = ref.watch(authServiceProvider).currentUser;
                    final imagePath = user?.photoUrl;
                    final userName = user?.displayName ?? 'Lecteur';
                    ImageProvider? imageProvider;

                    if (imagePath != null) {
                      if (imagePath.startsWith('http')) {
                        imageProvider = NetworkImage(imagePath);
                      } else {
                        imageProvider = FileImage(File(imagePath));
                      }
                    }

                    return Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedIndex = 3; // Switch to Profile tab
                            });
                          },
                          child: Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF2C74B3),
                              border: Border.all(color: Colors.white, width: 2.5),
                              image: imageProvider != null
                                  ? DecorationImage(
                                      image: imageProvider,
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: imageProvider == null
                                ? const Icon(
                                    Icons.person_rounded,
                                    color: Colors.white,
                                    size: 30,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Bienvenue,',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              _isGridView = !_isGridView;
            });
          },
        ),
        NotificationBellButton(
          color: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationsScreen(),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }


  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2647).withAlpha(10),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher un journal...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF2C74B3),
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
                  color: isSelected ? Colors.white : const Color(0xFF0A2647),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF2C74B3),
              checkmarkColor: Colors.white,
              elevation: isSelected ? 4 : 0,
              shadowColor: const Color(0xFF2C74B3).withAlpha(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF2C74B3)
                      : Colors.grey.shade200,
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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
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
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A2647).withAlpha(8),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
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
                      color: Color(0xFF0A2647),
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
                          color: Color(0xFF2C74B3),
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
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2647).withAlpha(8),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
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
                            color: Color(0xFF0A2647),
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
                            color: Color(0xFF2C74B3),
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2647).withAlpha(10),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_rounded,
                label: 'Accueil',
                index: 0,
              ),
              // Lecteur : "Catégories". Admin/Éditeur : "À venir" (fonctionnalités
              // pas encore implémentées, à suivre/proposer).
              _buildNavItem(
                icon: isAdminOrEditeur
                    ? Icons.construction_rounded
                    : Icons.category_rounded,
                label: isAdminOrEditeur ? 'À venir' : 'Catégories',
                index: 1,
              ),
              _buildNavItem(
                icon: Icons.forum_rounded,
                label: 'Conversations',
                index: 2,
              ),
              _buildNavItem(
                icon: Icons.person_rounded,
                label: 'Profil',
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2C74B3).withAlpha(25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color:
                  isSelected ? const Color(0xFF2C74B3) : Colors.grey.shade400,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF2C74B3),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
