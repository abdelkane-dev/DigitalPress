import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/services/app_notification_service.dart';

/// Modération des avis lecteurs par un administrateur : consultation de
/// l'ensemble des avis de la plateforme et suppression de ceux jugés
/// inappropriés. S'appuie sur les nouveaux points d'accès admin
/// `AdminReviewListView` / `AdminReviewDeleteView`.
class ManageReviewsScreen extends ConsumerStatefulWidget {
  const ManageReviewsScreen({super.key});

  @override
  ConsumerState<ManageReviewsScreen> createState() => _ManageReviewsScreenState();
}

class _ManageReviewsScreenState extends ConsumerState<ManageReviewsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _reviews = [];
  int? _ratingFilter;

  @override
  void initState() {
    super.initState();
    _load();
    ref.listenManual(realtimeEventProvider, (previous, next) {
      if (next != null) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(
        'publications/admin/reviews/',
        queryParameters: _ratingFilter != null ? {'rating': _ratingFilter} : null,
      );
      final raw = response.data is Map
          ? (response.data['results'] as List? ?? [])
          : (response.data as List? ?? []);
      _reviews = raw.cast<Map<String, dynamic>>();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cet avis ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
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
      await apiClient.delete('publications/admin/reviews/${review['id']}/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avis supprimé.')));
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modération des avis'),
        centerTitle: true,
        actions: [
          PopupMenuButton<int?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _ratingFilter = value);
              _load();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('Toutes les notes')),
              for (var i = 1; i <= 5; i++)
                PopupMenuItem(value: i, child: Text('$i étoile${i > 1 ? 's' : ''}')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur : $_error'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _reviews.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text('Aucun avis à modérer.')),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _reviews.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final review = _reviews[index];
                            final rating = (review['rating'] as num?)?.toInt() ?? 0;
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: const [
                                  BoxShadow(blurRadius: 8, color: Colors.black12, offset: Offset(0, 3)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Row(
                                        children: List.generate(
                                          5,
                                          (i) => Icon(
                                            i < rating ? Icons.star : Icons.star_border,
                                            size: 16,
                                            color: Colors.amber,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () => _delete(review),
                                      ),
                                    ],
                                  ),
                                  if ((review['comment']?.toString() ?? '').isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      child: Text(review['comment'].toString()),
                                    ),
                                  Text(
                                    'Publication : ${review['publication_title'] ?? review['publication'] ?? '—'}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                  Text(
                                    'Par : ${review['reader_username'] ?? review['reader'] ?? '—'}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
