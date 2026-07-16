import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

/// Page publique du profil d'un éditeur DigitalPress.
/// Accessible depuis la fiche d'un article — lecture seule, design premium.
/// Si [publisherId] est null, affiche et permet d'éditer le propre profil de l'éditeur connecté.
class PosterProfileScreen extends ConsumerStatefulWidget {
  final int? publisherId;

  const PosterProfileScreen({super.key, this.publisherId});

  @override
  ConsumerState<PosterProfileScreen> createState() =>
      _PosterProfileScreenState();
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
    setState(() { _loading = true; _error = null; });
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = widget.publisherId == null
          ? await apiClient.get('accounts/me/publisher-profile/')
          : await apiClient.get('accounts/publishers/public/${widget.publisherId}/');
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _isPublicView => widget.publisherId != null;

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Profil éditeur'),
          backgroundColor: const Color(0xFF0A2647),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text('Impossible de charger le profil\n$_error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer')),
              ],
            ),
          ),
        ),
      );
    }
    return _isPublicView ? _buildPublicView() : _buildEditView();
  }

  // ── VUE PUBLIQUE — design premium ──────────────────────────────────────────
  Widget _buildPublicView() {
    final data = _profile!;
    final username = data['username']?.toString() ?? '';
    final companyName = data['company_name']?.toString() ?? '';
    final website = data['website']?.toString() ?? '';
    final address = data['address']?.toString() ?? '';
    final siret = data['siret']?.toString() ?? '';
    final bio = data['bio']?.toString() ?? '';
    final isActive = data['is_active'] == true;
    final totalArticles = data['total_articles']?.toString() ?? '0';
    final publishedArticles = data['published_articles']?.toString() ?? '0';
    final totalViews = data['total_views']?.toString() ?? '0';
    final displayName = companyName.isNotEmpty ? companyName : username;
    final initials = _initials(displayName);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF0A2647),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0A2647), Color(0xFF2C74B3)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -60,
                      top: -60,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withAlpha(12),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -40,
                      bottom: -40,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF2C74B3).withAlpha(40),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2C74B3), Color(0xFF0A2647)],
                                ),
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(60),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (username.isNotEmpty && companyName.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '@$username',
                                style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 14),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.green.withAlpha(40) : Colors.red.withAlpha(40),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isActive ? Colors.green.shade300 : Colors.red.shade300,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isActive ? Icons.verified_rounded : Icons.pause_circle_outline,
                                    size: 14,
                                    color: isActive ? Colors.green.shade300 : Colors.red.shade300,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isActive ? 'Éditeur vérifié' : 'Compte suspendu',
                                    style: TextStyle(
                                      color: isActive ? Colors.green.shade200 : Colors.red.shade200,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats
                  Row(
                    children: [
                      Expanded(child: _StatCard(value: totalArticles, label: 'Articles', icon: Icons.article_rounded, color: const Color(0xFF0A2647))),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(value: publishedArticles, label: 'Publiés', icon: Icons.publish_rounded, color: const Color(0xFF2C74B3))),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(value: totalViews, label: 'Vues', icon: Icons.visibility_rounded, color: Color(0xFFEA580C))),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Bio
                  if (bio.isNotEmpty) ...[
                    _sectionTitle('À propos', Icons.info_outline_rounded),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: _cardDeco(),
                      child: Text(bio, style: const TextStyle(fontSize: 15, height: 1.65, color: Color(0xFF334155))),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Coordonnées
                  _sectionTitle('Coordonnées', Icons.contact_page_outlined),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: _cardDeco(),
                    child: Column(
                      children: [
                        if (website.isNotEmpty)
                          _infoTile(Icons.language_rounded, const Color(0xFF2C74B3), 'Site web', website, isLink: true),
                        if (address.isNotEmpty)
                          _infoTile(Icons.location_on_rounded, const Color(0xFFEA580C), 'Adresse', address),
                        if (siret.isNotEmpty)
                          _infoTile(Icons.badge_outlined, Colors.teal, 'SIRET / Enregistrement', siret),
                        if (website.isEmpty && address.isEmpty && siret.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Aucune coordonnée publique disponible.', style: TextStyle(color: Colors.grey)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Footer
                  Center(
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset('assets/app_icon.png', width: 36, height: 36, fit: BoxFit.cover),
                        ),
                        const SizedBox(height: 6),
                        Text('Éditeur sur DigitalPress', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF0A2647)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0A2647))),
      ],
    );
  }

  Widget _infoTile(IconData icon, Color color, String label, String value, {bool isLink = false}) {
    return InkWell(
      onTap: isLink
          ? () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('URL copiée dans le presse-papier'), duration: Duration(seconds: 2)),
              );
            }
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: isLink ? const Color(0xFF2C74B3) : const Color(0xFF1E293B),
                      fontWeight: FontWeight.w600,
                      decoration: isLink ? TextDecoration.underline : TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            if (isLink) Icon(Icons.copy_rounded, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    boxShadow: [BoxShadow(color: const Color(0xFF0A2647).withAlpha(8), blurRadius: 20, offset: const Offset(0, 6))],
  );

  // ── VUE ÉDITION (propre profil) ────────────────────────────────────────────
  Widget _buildEditView() {
    final data = _profile ?? {};
    final solde = data['solde']?.toString() ?? '0';
    final totalEarned = data['total_earned']?.toString() ?? '0';
    final commission = data['commission_rate']?.toString() ?? '0';
    final isActive = data['is_active'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Mon profil éditeur'),
        centerTitle: true,
        backgroundColor: const Color(0xFF0A2647),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.orange.shade700, Colors.orange.shade500]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(isActive ? Icons.check_circle : Icons.pause_circle_filled, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      isActive ? 'Compte actif' : 'Compte suspendu',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _MiniInfoPill(label: 'Solde', value: '$solde FCFA'),
                    const SizedBox(width: 10),
                    _MiniInfoPill(label: 'Gagné', value: '$totalEarned FCFA'),
                    const SizedBox(width: 10),
                    _MiniInfoPill(label: 'Commission', value: '$commission%'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Ces valeurs sont gérées exclusivement par l'administration.",
                  style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(180)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Informations publiques',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0A2647))),
          const SizedBox(height: 14),
          Form(
            key: _formKey,
            child: Column(
              children: [
                _field(_companyController, "Nom de l'entreprise / du journal", Icons.business_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null),
                const SizedBox(height: 14),
                _field(_websiteController, 'Site web', Icons.language_rounded, type: TextInputType.url),
                const SizedBox(height: 14),
                _field(_addressController, 'Adresse', Icons.location_on_rounded),
                const SizedBox(height: 14),
                _field(_siretController, "SIRET / Numéro d'enregistrement", Icons.badge_outlined),
                const SizedBox(height: 14),
                _field(_bioController, 'Description / bio publique', Icons.info_outline_rounded, lines: 4),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A2647),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    int lines = 1,
    TextInputType? type,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: c,
      maxLines: lines,
      keyboardType: type,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF2C74B3)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2C74B3), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}

// ─── Widgets auxiliaires ──────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard({required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withAlpha(20), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _MiniInfoPill extends StatelessWidget {
  final String label;
  final String value;

  const _MiniInfoPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(30),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withAlpha(60)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withAlpha(180))),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
