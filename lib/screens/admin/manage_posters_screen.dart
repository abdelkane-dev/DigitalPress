import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/admin_demo_store.dart';
import '../../model/admin_poster.dart';
import 'poster_details_screen.dart';

enum PosterFilter { all, active, warned, banned }

class ManagePostersScreen extends ConsumerStatefulWidget {
  const ManagePostersScreen({super.key});

  @override
  ConsumerState<ManagePostersScreen> createState() =>
      _ManagePostersScreenState();
}

class _ManagePostersScreenState extends ConsumerState<ManagePostersScreen> {
  final TextEditingController _searchController = TextEditingController();
  PosterFilter _selectedFilter = PosterFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showWarningDialog(AdminPoster poster) async {
    final TextEditingController reasonController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Envoyer un avertissement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Poster concerné : ${poster.fullName}'),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Ex: diffusion d’informations non vérifiées',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) return;
                Navigator.pop(context, reason);
              },
              child: const Text('Envoyer'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      try {
        await ref
            .read(adminDemoStoreProvider.notifier)
            .addWarning(posterId: poster.id, reason: result);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'envoi : $e')),
        );
        return;
      }

      final updatedPoster = ref
          .read(adminDemoStoreProvider)
          .firstWhere((item) => item.id == poster.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Avertissement envoyé à ${poster.fullName} '
            '(${updatedPoster.warnings} au total).',
          ),
        ),
      );
    }
  }

  Future<void> _confirmToggleBan(AdminPoster poster) async {
    final actionText = poster.isBanned ? 'débannir' : 'bannir';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            '${actionText[0].toUpperCase()}${actionText.substring(1)} ce poster',
          ),
          content: Text(
            'Voulez-vous vraiment $actionText ${poster.fullName} ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await ref.read(adminDemoStoreProvider.notifier).toggleBan(poster.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              poster.isBanned
                  ? '${poster.fullName} a été réactivé(e).'
                  : '${poster.fullName} a été désactivé(e).',
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openPosterDetails(AdminPoster poster) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PosterDetailsScreen(
          poster: poster,
          onWarn: () async {
            Navigator.pop(context);
            await _showWarningDialog(poster);
          },
          onToggleBan: () async {
            Navigator.pop(context);
            await _confirmToggleBan(poster);
          },
          onUpdateCommission: (rate) async {
            await _updateCommissionRate(poster, rate);
          },
        ),
      ),
    );
  }

  Future<void> _updateCommissionRate(AdminPoster poster, double rate) async {
    try {
      await ref.read(adminDemoStoreProvider.notifier).updateCommissionRate(poster.id, rate);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Commission de ${poster.mediaName} mise à jour : ${rate.toStringAsFixed(1)} %'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
      );
    }
  }

  Color _statusColor(AdminPoster poster) {
    if (poster.isBanned) return Colors.red;
    if (poster.warnings > 0) return Colors.orange;
    return Colors.green;
  }

  String _statusText(AdminPoster poster) {
    if (poster.isBanned) return 'Banni';
    if (poster.warnings > 0) return 'Sous surveillance';
    return 'Actif';
  }

  List<AdminPoster> _filteredPosters(List<AdminPoster> posters) {
    final query = _searchController.text.trim().toLowerCase();

    return posters.where((poster) {
      final matchesSearch =
          poster.fullName.toLowerCase().contains(query) ||
          poster.mediaName.toLowerCase().contains(query) ||
          poster.email.toLowerCase().contains(query);

      final matchesFilter = switch (_selectedFilter) {
        PosterFilter.all => true,
        PosterFilter.active => !poster.isBanned && poster.warnings == 0,
        PosterFilter.warned => !poster.isBanned && poster.warnings > 0,
        PosterFilter.banned => poster.isBanned,
      };

      return matchesSearch && matchesFilter;
    }).toList();
  }

  Widget _buildFilterChip(String label, PosterFilter filter) {
    final isSelected = _selectedFilter == filter;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedFilter = filter;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final posters = ref.watch(adminDemoStoreProvider);
    final filteredPosters = _filteredPosters(posters);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gérer les posters'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: () => ref.read(adminDemoStoreProvider.notifier).loadPublishers(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Rechercher un poster...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('Tous', PosterFilter.all),
                const SizedBox(width: 8),
                _buildFilterChip('Actifs', PosterFilter.active),
                const SizedBox(width: 8),
                _buildFilterChip('Avertis', PosterFilter.warned),
                const SizedBox(width: 8),
                _buildFilterChip('Bannis', PosterFilter.banned),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: filteredPosters.isEmpty
                ? const Center(child: Text('Aucun poster trouvé.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredPosters.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final poster = filteredPosters[index];

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openPosterDetails(poster),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 8,
                                color: Colors.black12,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      poster.fullName,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _statusColor(
                                        poster,
                                      ).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _statusText(poster),
                                      style: TextStyle(
                                        color: _statusColor(poster),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Média: ${poster.mediaName}'),
                              Text('Email: ${poster.email}'),
                              const SizedBox(height: 8),
                              Text(
                                'Avertissements: ${poster.warnings}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: poster.isBanned
                                        ? null
                                        : () => _showWarningDialog(poster),
                                    icon: const Icon(
                                      Icons.warning_amber_rounded,
                                    ),
                                    label: const Text('Avertir'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _confirmToggleBan(poster),
                                    icon: Icon(
                                      poster.isBanned
                                          ? Icons.lock_open
                                          : Icons.block,
                                    ),
                                    label: Text(
                                      poster.isBanned ? 'Débannir' : 'Bannir',
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _openPosterDetails(poster),
                                    child: const Text('Voir détails'),
                                  ),
                                ],
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
    );
  }
}
