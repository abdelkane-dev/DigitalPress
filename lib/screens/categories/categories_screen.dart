import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/favorites_service.dart';
import '../../model/reader_category.dart';
import 'reader_playlist_detail_screen.dart';
import '../../widgets/main_app_bar.dart';

/// Page « Catégories » du Lecteur.
/// N'affiche que les playlists personnelles du lecteur (ex-onglet « Mes
/// Playlists »), stylisées avec des cartes colorées identiques aux cartes
/// de catégories globales.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  bool _isGridView = true;

  // ──────────────────────────── Couleurs des cartes ────────────────────────

  static const List<Color> _cardColors = [
    Color(0xFF2C74B3),
    Color(0xFF10B981),
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
    Color(0xFF06B6D4),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
  ];

  Color _colorForId(int id) =>
      _cardColors[id.hashCode.toUnsigned(32) % _cardColors.length];

  // ──────────────────────────── Dialogues ──────────────────────────────────

  Future<void> _showCreateCategoryDialog(BuildContext context) async {
    final nameController = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Nouvelle catégorie'),
              content: TextField(
                controller: nameController,
                enabled: !isLoading,
                decoration: InputDecoration(
                  labelText: 'Nom de la catégorie',
                  hintText: 'Ex: À lire plus tard, Cuisine...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (nameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                  content: Text('Veuillez entrer un nom'),
                                  backgroundColor: Colors.red),
                            );
                            return;
                          }
                          setDialogState(() => isLoading = true);
                          try {
                            await ref
                                .read(favoritesServiceProvider)
                                .createReaderCategory(
                                    nameController.text.trim());
                            ref.invalidate(readerCategoriesProvider);
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                    content: Text('Erreur : $e'),
                                    backgroundColor: Colors.red),
                              );
                            }
                          } finally {
                            if (ctx.mounted) {
                              setDialogState(() => isLoading = false);
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Créer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteCategory(
      BuildContext context, ReaderCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer cette catégorie ?'),
        content: Text(
          'La catégorie « ${category.name} » sera supprimée. '
          'Les articles qui y étaient rangés resteront dans vos favoris.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref
            .read(favoritesServiceProvider)
            .deleteReaderCategory(category.id);
        ref.invalidate(readerCategoriesProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ──────────────────────────── Build principal ────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ─── CORRECTIF : même bug que ProfileScreen (voir ce fichier pour
      // le détail) — fond transparent qui laissait apparaître un écran
      // noir quand le contenu du CustomScrollView ne remplit pas l'écran.
      body: CustomScrollView(
        slivers: [
          MainAppBar(
            title: 'catégories',
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
                onPressed: () => setState(() => _isGridView = !_isGridView),
              ),
            ),
          ),
          ..._buildCategoriesSlivers(context),
        ],
      ),
    );
  }


  // ──────────────────────────── Liste des catégories (playlists) ───────────

  List<Widget> _buildCategoriesSlivers(BuildContext context) {
    final categoriesAsync = ref.watch(readerCategoriesProvider);

    return [
      categoriesAsync.when(
        loading: () => const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
        error: (e, _) => SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text('Erreur : $e', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        data: (categories) => categories.isEmpty
            ? SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.category_outlined,
                          size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucune catégorie pour le moment',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Créez une catégorie, puis ajoutez-y\nvos articles favoris depuis leur page.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade400),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showCreateCategoryDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Créer une catégorie'),
                      ),
                    ],
                  ),
                ),
              )
            : SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: _isGridView
                    ? SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.0,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildCategoryCard(context, categories[index]),
                          childCount: categories.length,
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildCategoryTile(context, categories[index]),
                          childCount: categories.length,
                        ),
                      ),
              ),
      ),
    ];
  }

  // ──────────────────────────── Carte catégorie (grille) ───────────────────

  Widget _buildCategoryCard(BuildContext context, ReaderCategory category) {
    final color = _colorForId(category.id);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReaderPlaylistDetailScreen(
            categoryId: category.id,
            categoryName: category.name,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withValues(alpha: 0.7)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: color.withAlpha(80),
                blurRadius: 20,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: Colors.white.withAlpha(25)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(50),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getCategoryIcon(category.name),
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.white70, size: 20),
                        onPressed: () =>
                            _confirmDeleteCategory(context, category),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${category.articlesCount} article(s)',
                    style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────── Tuile catégorie (liste) ────────────────────

  Widget _buildCategoryTile(BuildContext context, ReaderCategory category) {
    final color = _colorForId(category.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_getCategoryIcon(category.name), color: color),
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.black87),
        ),
        subtitle: Text(
          '${category.articlesCount} article(s)',
          style: TextStyle(color: Colors.grey.shade500),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _confirmDeleteCategory(context, category),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReaderPlaylistDetailScreen(
              categoryId: category.id,
              categoryName: category.name,
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────── Icône selon le nom ─────────────────────────

  IconData _getCategoryIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('actualit')) return Icons.newspaper_rounded;
    if (n.contains('sport')) return Icons.sports_soccer_rounded;
    if (n.contains('culture')) return Icons.theater_comedy_rounded;
    if (n.contains('econ') || n.contains('finance')) {
      return Icons.trending_up_rounded;
    }
    if (n.contains('tech')) return Icons.computer_rounded;
    if (n.contains('sant') || n.contains('health')) {
      return Icons.favorite_rounded;
    }
    if (n.contains('politique')) return Icons.gavel_rounded;
    if (n.contains('educat')) return Icons.school_rounded;
    return Icons.category_rounded;
  }
}
