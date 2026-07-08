import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

/// Gestion globale des comptes utilisateurs par un administrateur :
/// lecteurs, éditeurs et autres admins. Permet de rechercher, filtrer par
/// rôle, suspendre/réactiver un compte, et voir ses informations clés.
///
/// Contrairement à l'ancien tableau de bord admin (qui ne permettait de
/// gérer que les éditeurs via `manage_posters_screen`), cet écran couvre
/// TOUS les types de comptes, y compris les lecteurs — une fonctionnalité
/// jusqu'ici totalement absente côté admin.
class ManageUsersScreen extends ConsumerStatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  ConsumerState<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends ConsumerState<ManageUsersScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  String? _roleFilter;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final apiClient = ref.read(apiClientProvider);
      final params = <String, dynamic>{};
      if (_roleFilter != null) params['role'] = _roleFilter;
      if (_searchController.text.trim().isNotEmpty) {
        params['search'] = _searchController.text.trim();
      }
      final response = await apiClient.get('accounts/users/', queryParameters: params);
      final raw = response.data is Map
          ? (response.data['results'] as List? ?? [])
          : (response.data as List? ?? []);
      _users = raw.cast<Map<String, dynamic>>();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> user) async {
    final isActive = user['is_active'] != false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isActive ? 'Suspendre ce compte ?' : 'Réactiver ce compte ?'),
        content: Text(
          isActive
              ? '${user['username']} ne pourra plus se connecter tant que le compte est suspendu.'
              : '${user['username']} pourra de nouveau se connecter normalement.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? Colors.red : Colors.green,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isActive ? 'Suspendre' : 'Réactiver', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.patch(
        'accounts/users/${user['id']}/',
        data: {'is_active': !isActive},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isActive ? 'Compte suspendu.' : 'Compte réactivé.')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer définitivement ce compte ?'),
        content: Text(
          'Cette action est irréversible et supprimera toutes les données '
          'associées à ${user['username']}.',
        ),
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
      await apiClient.delete('accounts/users/${user['id']}/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compte supprimé.')));
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'admin':
        return Colors.purple;
      case 'publisher':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'admin':
        return 'Administrateur';
      case 'publisher':
        return 'Éditeur';
      default:
        return 'Lecteur';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestion des utilisateurs'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher (nom, email)...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 10),
                PopupMenuButton<String?>(
                  icon: const Icon(Icons.filter_list),
                  onSelected: (value) {
                    setState(() => _roleFilter = value);
                    _load();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: null, child: Text('Tous les rôles')),
                    PopupMenuItem(value: 'reader', child: Text('Lecteurs')),
                    PopupMenuItem(value: 'publisher', child: Text('Éditeurs')),
                    PopupMenuItem(value: 'admin', child: Text('Administrateurs')),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Erreur : $_error'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _users.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 120),
                                  Center(child: Text('Aucun utilisateur trouvé.')),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _users.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final user = _users[index];
                                  final isActive = user['is_active'] != false;
                                  final role = user['role']?.toString();
                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: const [
                                        BoxShadow(blurRadius: 8, color: Colors.black12, offset: Offset(0, 3)),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: _roleColor(role).withOpacity(0.15),
                                          child: Text(
                                            (user['username']?.toString() ?? '?')[0].toUpperCase(),
                                            style: TextStyle(color: _roleColor(role), fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      user['username']?.toString() ?? '',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: _roleColor(role).withOpacity(0.12),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      _roleLabel(role),
                                                      style: TextStyle(fontSize: 11, color: _roleColor(role), fontWeight: FontWeight.w600),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                user['email']?.toString() ?? '',
                                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                              ),
                                              if (!isActive)
                                                const Padding(
                                                  padding: EdgeInsets.only(top: 4),
                                                  child: Text(
                                                    'Compte suspendu',
                                                    style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          onSelected: (action) {
                                            if (action == 'toggle') _toggleActive(user);
                                            if (action == 'delete') _confirmDelete(user);
                                          },
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              value: 'toggle',
                                              child: Text(isActive ? 'Suspendre' : 'Réactiver'),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Supprimer', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}
