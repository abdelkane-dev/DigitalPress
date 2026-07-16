import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/favorites_service.dart';
import '../model/publication.dart';
import '../model/reader_category.dart';

/// Affiche le sélecteur "Ajouter aux favoris" : le Lecteur choisit dans
/// quelle(s) catégorie(s) personnelle(s) (playlists façon YouTube) ranger
/// l'article, ou en crée une nouvelle à la volée.
void showAddToFavoritesSheet(BuildContext context, Publication publication) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _AddToFavoritesSheet(publication: publication),
  );
}

class _AddToFavoritesSheet extends ConsumerStatefulWidget {
  final Publication publication;
  const _AddToFavoritesSheet({required this.publication});

  @override
  ConsumerState<_AddToFavoritesSheet> createState() => _AddToFavoritesSheetState();
}

class _AddToFavoritesSheetState extends ConsumerState<_AddToFavoritesSheet> {
  final Set<int> _selectedCategoryIds = {};
  final TextEditingController _newCategoryController = TextEditingController();
  bool _isSaving = false;
  bool _isCreatingCategory = false;
  bool _initialized = false;

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
  }

  Future<void> _createCategory() async {
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isCreatingCategory = true);
    try {
      final category = await ref.read(favoritesServiceProvider).createReaderCategory(name);
      ref.invalidate(readerCategoriesProvider);
      setState(() {
        _selectedCategoryIds.add(category.id);
        _newCategoryController.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingCategory = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(favoritesServiceProvider).addOrUpdateFavorite(
            widget.publication.id,
            categoryIds: _selectedCategoryIds.toList(),
          );
      ref.invalidate(favoritesProvider(null));
      for (final id in _selectedCategoryIds) {
        ref.invalidate(favoritesProvider(id));
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ajouté à vos favoris ✓'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removeFavorite() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(favoritesServiceProvider).removeFavorite(widget.publication.id);
      ref.invalidate(favoritesProvider(null));
      for (final id in _selectedCategoryIds) {
        ref.invalidate(favoritesProvider(id));
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Retiré de vos favoris')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(readerCategoriesProvider);
    // Pré-sélectionne les playlists dans lesquelles l'article est déjà rangé.
    final favoritesAsync = ref.watch(favoritesProvider(null));
    favoritesAsync.whenData((favorites) {
      if (!_initialized) {
        final existing = favorites.where((f) => f.id == widget.publication.id).toList();
        if (existing.isNotEmpty) {
          _selectedCategoryIds.addAll(existing.first.categoryIds);
        }
        _initialized = true;
      }
    });

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bookmark_rounded, color: Color(0xFF2C74B3)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ajouter "${widget.publication.title}" aux favoris',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Choisissez une ou plusieurs playlists (facultatif) :',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                categoriesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('Erreur : $e'),
                  data: (categories) {
                    if (categories.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Vous n\'avez pas encore de playlist. Créez-en une ci-dessous.',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                        ),
                      );
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((ReaderCategory cat) {
                        final selected = _selectedCategoryIds.contains(cat.id);
                        return FilterChip(
                          label: Text(cat.name),
                          selected: selected,
                          selectedColor: const Color(0xFF2C74B3).withAlpha(40),
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedCategoryIds.add(cat.id);
                              } else {
                                _selectedCategoryIds.remove(cat.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newCategoryController,
                        decoration: InputDecoration(
                          hintText: 'Nouvelle playlist (ex: À lire plus tard)',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isCreatingCategory
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(
                            icon: const Icon(Icons.add_circle, color: Color(0xFF2C74B3)),
                            onPressed: _createCategory,
                          ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : _removeFavorite,
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Retirer des favoris'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A2647),
                          foregroundColor: Colors.white,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Enregistrer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
