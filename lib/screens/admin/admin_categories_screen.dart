import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/services/app_notification_service.dart';
import '../../widgets/main_app_bar.dart';

/// Gestion des catégories de publications par un administrateur :
/// créer, renommer ou supprimer une catégorie (taxonomie globale utilisée
/// par les éditeurs à la création d'une publication).
///
/// Remplace l'ancien espace « Retraits éditeurs » (supprimé de la
/// plateforme) par une fonction réellement utile côté administration.
///
/// [embedded=true] : la page est affichée dans les 4 onglets principaux de
/// l'app → son en-tête reprend celui des autres pages principales (logo +
/// titre à gauche, icônes à droite). Sur sa propre route (/admin/categories)
/// elle garde son en-tête actuel.
class AdminCategoriesScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const AdminCategoriesScreen({super.key, this.embedded = false});

  @override
  ConsumerState<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends ConsumerState<AdminCategoriesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _categories = [];
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    ref.listenManual(realtimeEventProvider, (previous, next) {
      if (next != null) _load();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('publications/categories/');
      final raw = response.data is Map
          ? (response.data['results'] as List? ?? [])
          : (response.data as List? ?? []);
      _categories = raw.cast<Map<String, dynamic>>();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post(
        'publications/categories/',
        data: {'name': name},
      );
      _nameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Catégorie créée.')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  Future<void> _rename(Map<String, dynamic> category) async {
    final controller = TextEditingController(
      text: category['name']?.toString() ?? '',
    );
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renommer la catégorie'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nom'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.patch(
        'publications/categories/${category['id']}/',
        data: {'name': newName},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Catégorie renommée.')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette catégorie ?'),
        content: Text(
          'La catégorie « ${category['name']} » sera supprimée. '
          'Les publications existantes ne seront plus associées à une catégorie.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.delete('publications/categories/${category['id']}/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Catégorie supprimée.')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  Widget _buildCategoryTile(Map<String, dynamic> category) {
    final pubCount = category['publications_count']?.toString();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            color: Colors.black12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.shade100,
            child: Icon(Icons.category_rounded, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category['name']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                if (pubCount != null)
                  Text(
                    '$pubCount publication(s)',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _rename(category),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _delete(category),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _nameController,
        decoration: InputDecoration(
          hintText: 'Nom de la nouvelle catégorie (ex: Politique)',
          prefixIcon: const Icon(Icons.category_outlined),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onSubmitted: (_) => _create(),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Erreur : $_error'));
    if (_categories.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text('Aucune catégorie. Créez-en une !')),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      itemCount: _categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _buildCategoryTile(_categories[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ─── Mode intégré (onglets principaux) : en-tête comme les autres
    // pages principales (MainAppBar), contenu en CustomScrollView.
    if (widget.embedded) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _create,
          icon: const Icon(Icons.add),
          label: const Text('Créer'),
        ),
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Pas de logo sur cet onglet (demande explicite) — titre seul,
            // bien mis en évidence, comme sur les autres pages principales.
            MainAppBar(title: 'catégories'),
            SliverToBoxAdapter(child: _buildInputField()),
            if (_loading || _error != null || _categories.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildList(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildCategoryTile(_categories[index]),
                    ),
                    childCount: _categories.length,
                  ),
                ),
              ),
            // Espace pour ne pas masquer la dernière carte sous la barre
            // de navigation principale.
            const SliverToBoxAdapter(child: SizedBox(height: 140)),
          ],
        ),
      );
    }

    // ─── Mode route dédiée : en-tête actuel (inchangé). ────────────────
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des catégories'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Créer'),
      ),
      body: Column(
        children: [
          _buildInputField(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }
}
