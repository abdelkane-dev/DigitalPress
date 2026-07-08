import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

/// Permet à un éditeur de consulter et modifier les informations publiques
/// de son entreprise/journal (nom, site web, bio, adresse, SIRET), ainsi que
/// de visualiser en lecture seule son taux de commission et son solde —
/// ces deux derniers restant strictement modifiables par un administrateur
/// uniquement (voir la protection ajoutée dans PublisherProfileSerializer).
class PosterProfileScreen extends ConsumerStatefulWidget {
  const PosterProfileScreen({super.key});

  @override
  ConsumerState<PosterProfileScreen> createState() => _PosterProfileScreenState();
}

class _PosterProfileScreenState extends ConsumerState<PosterProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _websiteController = TextEditingController();
  final _addressController = TextEditingController();
  final _siretController = TextEditingController();
  final _bioController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _companyController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    _siretController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('accounts/me/publisher-profile/');
      final data = response.data as Map<String, dynamic>;
      _profile = data;
      _companyController.text = data['company_name']?.toString() ?? '';
      _websiteController.text = data['website']?.toString() ?? '';
      _addressController.text = data['address']?.toString() ?? '';
      _siretController.text = data['siret']?.toString() ?? '';
      _bioController.text = data['bio']?.toString() ?? '';
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.patch(
        'accounts/me/publisher-profile/',
        data: {
          'company_name': _companyController.text.trim(),
          'website': _websiteController.text.trim(),
          'address': _addressController.text.trim(),
          'siret': _siretController.text.trim(),
          'bio': _bioController.text.trim(),
        },
      );
      _profile = response.data as Map<String, dynamic>;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour avec succès.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil éditeur'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text('Erreur : $_error', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_profile != null) _buildReadOnlySummary(),
                    const SizedBox(height: 20),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _companyController,
                            decoration: const InputDecoration(
                              labelText: 'Nom de l\'entreprise / du journal',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _websiteController,
                            decoration: const InputDecoration(
                              labelText: 'Site web',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: 'Adresse',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _siretController,
                            decoration: const InputDecoration(
                              labelText: 'SIRET / Numéro d\'enregistrement',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _bioController,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Description / bio publique',
                              border: OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade700,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildReadOnlySummary() {
    final solde = _profile!['solde']?.toString() ?? '0';
    final totalEarned = _profile!['total_earned']?.toString() ?? '0';
    final commission = _profile!['commission_rate']?.toString() ?? '0';
    final isActive = _profile!['is_active'] == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isActive ? Icons.check_circle : Icons.pause_circle_filled,
                color: isActive ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                isActive ? 'Compte actif' : 'Compte suspendu',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Solde disponible : $solde FCFA'),
          Text('Total gagné : $totalEarned FCFA'),
          Text('Taux de commission plateforme : $commission%'),
          const SizedBox(height: 4),
          Text(
            'Ces valeurs sont gérées exclusivement par l\'administration.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
