import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/publisher_verification_service.dart';

/// Étape 2/3 de l'onboarding éditeur : ici l'admin valide ou rejette les
/// dossiers de vérification soumis (voir poster_verification_screen.dart
/// côté éditeur). Notification + email sont envoyés automatiquement par le
/// backend à la décision.
class AdminVerificationsScreen extends ConsumerStatefulWidget {
  const AdminVerificationsScreen({super.key});

  @override
  ConsumerState<AdminVerificationsScreen> createState() => _AdminVerificationsScreenState();
}

class _AdminVerificationsScreenState extends ConsumerState<AdminVerificationsScreen> {
  String _statusFilter = 'pending';
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await ref
          .read(publisherVerificationServiceProvider)
          .adminListVerifications(status: _statusFilter);
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur de chargement des dossiers.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(Map<String, dynamic> item, bool approve) async {
    String? reason;
    if (!approve) {
      reason = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('Motif du rejet'),
            content: TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Ex : document RCCM illisible, adresse incohérente…',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Rejeter'),
              ),
            ],
          );
        },
      );
      if (reason == null || reason.isEmpty) return;
    }

    try {
      await ref.read(publisherVerificationServiceProvider).adminReview(
            item['id'] as int,
            approve: approve,
            rejectionReason: reason,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Dossier approuvé.' : 'Dossier rejeté.')),
      );
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la décision.')),
      );
    }
  }

  void _showDetails(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Text(item['legal_company_name']?.toString() ?? '',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('@${item['publisher_username'] ?? ''}', style: const TextStyle(color: Colors.grey)),
            const Divider(height: 24),
            _row('N° RCCM / registre', item['registration_number']),
            _row('NIF / fiscal', item['tax_id']),
            _row('Adresse', item['official_address']),
            _row('Ville / Pays', '${item['city'] ?? ''}, ${item['country'] ?? ''}'),
            _row('Téléphone', item['phone_number']),
            _row('Représentant légal', item['legal_representative_name']),
            _row("N° CNI / passeport", item['legal_representative_id_number']),
            _row('Accréditation presse', item['press_accreditation_number']),
            _row('Site web', item['website']),
            const Divider(height: 24),
            const Text('Documents', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _docLink("Pièce d'identité", item['id_document_url']),
            _docLink('Certificat RCCM', item['registration_document_url']),
            _docLink('Document additionnel', item['additional_document_url']),
            const SizedBox(height: 20),
            if (item['status'] == 'pending')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _review(item, false);
                      },
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Rejeter'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _review(item, true);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('Approuver'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, dynamic value) {
    final v = value?.toString() ?? '';
    if (v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(v),
        ],
      ),
    );
  }

  Widget _docLink(String label, dynamic url) {
    final u = url?.toString() ?? '';
    if (u.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          TextButton(
            onPressed: () async {
              final uri = Uri.tryParse(u);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Voir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérifications éditeurs'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('pending', 'En attente'),
                  _filterChip('approved', 'Validés'),
                  _filterChip('rejected', 'Rejetés'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('Aucun dossier dans cette catégorie.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final overdue = item['is_overdue'] == true;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          onTap: () => _showDetails(item),
                          title: Text(item['legal_company_name']?.toString() ?? ''),
                          subtitle: Text('@${item['publisher_username'] ?? ''} · ${item['city'] ?? ''}'),
                          trailing: overdue
                              ? const Chip(
                                  label: Text('En retard', style: TextStyle(color: Colors.white, fontSize: 11)),
                                  backgroundColor: Colors.red,
                                )
                              : const Icon(Icons.chevron_right_rounded),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _statusFilter = value);
          _load();
        },
      ),
    );
  }
}
