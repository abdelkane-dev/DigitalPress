import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/roadmap_service.dart';
import '../../model/feature_item.dart';
import '../../widgets/notification_bell_button.dart';
import '../notifications/notifications_screen.dart';
import '../../widgets/main_app_bar.dart';

/// Page "Fonctionnalités à venir".
///
/// Remplace, pour les rôles Admin et Éditeur, l'ancienne page "Catégories"
/// (qui n'a de sens que pour le Lecteur, et reste inchangée pour lui).
/// Ici, Admin et Éditeur peuvent consulter et proposer des fonctionnalités
/// pas encore implémentées mais utiles, et suivre leur avancement.
class FeatureRoadmapScreen extends ConsumerStatefulWidget {
  const FeatureRoadmapScreen({super.key});

  @override
  ConsumerState<FeatureRoadmapScreen> createState() =>
      _FeatureRoadmapScreenState();
}

class _FeatureRoadmapScreenState extends ConsumerState<FeatureRoadmapScreen> {
  bool _isGridView = false;

  static const _statusLabels = {
    'a_venir': 'À venir',
    'en_cours': 'En cours',
    'fait': 'Réalisé',
    'rejete': 'Non retenu',
  };

  static const _statusColors = {
    'a_venir': Color(0xFF64748B),
    'en_cours': Color(0xFFF59E0B),
    'fait': Color(0xFF10B981),
    'rejete': Color(0xFFEF4444),
  };

  Future<void> _showSuggestDialog(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Proposer une fonctionnalité'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      enabled: !isLoading,
                      decoration: InputDecoration(
                        labelText: 'Titre',
                        hintText: 'Ex : Export PDF des statistiques',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      enabled: !isLoading,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description (optionnel)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Cette suggestion sera ajoutée à la roadmap avec le statut "À venir".',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (titleController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Veuillez entrer un titre'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          setState(() => isLoading = true);
                          try {
                            await ref
                                .read(roadmapServiceProvider)
                                .createFeature(
                                  title: titleController.text.trim(),
                                  description:
                                      descriptionController.text.trim(),
                                );
                            ref.invalidate(roadmapListProvider);
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erreur : $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setState(() => isLoading = false);
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Proposer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAdminActions(
    BuildContext context,
    WidgetRef ref,
    FeatureItem feature,
  ) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Changer le statut',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              ..._statusLabels.entries.map(
                (entry) => ListTile(
                  leading: Icon(Icons.circle,
                      size: 12, color: _statusColors[entry.key]),
                  title: Text(entry.value),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await ref
                          .read(roadmapServiceProvider)
                          .updateStatus(feature.id, entry.key);
                      ref.invalidate(roadmapListProvider);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Erreur : $e'),
                              backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Supprimer',
                    style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await ref
                        .read(roadmapServiceProvider)
                        .deleteFeature(feature.id);
                    ref.invalidate(roadmapListProvider);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Erreur : $e'),
                            backgroundColor: Colors.red),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final featuresAsync = ref.watch(roadmapListProvider);
    final user = ref.watch(authServiceProvider).currentUser;
    final isAdmin = user?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90.0),
        child: FloatingActionButton(
          onPressed: () => _showSuggestDialog(context, ref),
          tooltip: 'Proposer une fonctionnalité',
          child: const Icon(Icons.add, size: 28),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(roadmapListProvider),
        child: CustomScrollView(
          slivers: [
            MainAppBar(
              title: 'Roadmap',
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
            featuresAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 12),
                      Text('Erreur : $error', textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
              data: (features) => features.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.construction_rounded,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text(
                              'Aucune fonctionnalité en préparation',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _showSuggestDialog(context, ref),
                              icon: const Icon(Icons.add),
                              label: const Text('Proposer une fonctionnalité'),
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
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.25,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildFeatureCard(
                                  context,
                                  ref,
                                  features[index],
                                  isAdmin,
                                  isGrid: true,
                                ),
                                childCount: features.length,
                              ),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildFeatureCard(
                                  context,
                                  ref,
                                  features[index],
                                  isAdmin,
                                  isGrid: false,
                                ),
                                childCount: features.length,
                              ),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildFeatureCard(
    BuildContext context,
    WidgetRef ref,
    FeatureItem feature,
    bool isAdmin, {
    bool isGrid = false,
  }) {
    final color = _statusColors[feature.status] ?? Colors.grey;

    if (isGrid) {
      return Container(
        padding: const EdgeInsets.all(12),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    feature.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isAdmin)
                  GestureDetector(
                    onTap: () => _showAdminActions(context, ref, feature),
                    child: const Icon(Icons.more_vert, size: 16, color: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (feature.description.isNotEmpty)
              Expanded(
                child: Text(
                  feature.description,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              const Spacer(),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    feature.statusDisplay,
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w800, color: color),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  feature.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                  onPressed: () => _showAdminActions(context, ref, feature),
                ),
            ],
          ),
          if (feature.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              feature.description,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  feature.statusDisplay,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800, color: color),
                ),
              ),
              const Spacer(),
              if (feature.createdByName != null)
                Text(
                  'Proposé par ${feature.createdByName}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
