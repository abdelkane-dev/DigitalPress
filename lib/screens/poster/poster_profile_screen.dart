import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/api/api_client.dart';
import '../../core/services/auth_service.dart';

/// Page publique du profil d'un éditeur DigitalPress.
/// Design inspiré de TikTok (minimaliste, axé créateur).
class PosterProfileScreen extends ConsumerStatefulWidget {
  final int? publisherId;
  const PosterProfileScreen({super.key, this.publisherId});

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
        Navigator.pop(context); // Fermer le bottom sheet
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

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (xfile == null) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mise à jour de la photo en cours...')),
      );
    }

    try {
      final authService = ref.read(authServiceProvider);
      await authService.updateProfile(avatarFile: xfile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo de profil mise à jour avec succès!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la mise à jour : $e')),
        );
      }
    }
  }

  bool get _isPublicView => widget.publisherId != null;

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  void _openEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFF7ED),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateSheet) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Modifier le profil',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 24),
                      // Private stats
                      if (!_isPublicView) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildPrivateStat('Solde', '${_profile?['solde'] ?? 0} FCFA'),
                              _buildPrivateStat('Gagné', '${_profile?['total_earned'] ?? 0} FCFA'),
                              _buildPrivateStat('Commission', '${_profile?['commission_rate'] ?? 0}%'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      _field(_companyController, "Nom de l'entreprise", Icons.business_rounded,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null),
                      const SizedBox(height: 14),
                      _field(_websiteController, 'Site web', Icons.language_rounded, type: TextInputType.url),
                      const SizedBox(height: 14),
                      _field(_addressController, 'Adresse', Icons.location_on_rounded),
                      const SizedBox(height: 14),
                      _field(_siretController, "SIRET", Icons.badge_outlined),
                      const SizedBox(height: 14),
                      _field(_bioController, 'Biographie', Icons.info_outline_rounded, lines: 3),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _saving ? null : () async {
                            setStateSheet(() => _saving = true);
                            await _save();
                            if (mounted) setStateSheet(() => _saving = false);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEA580C),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _saving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text('Paramètres', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.bar_chart_rounded, color: Colors.black87),
                title: const Text('Statistiques détaillées', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/poster/statistics');
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_rounded, color: Colors.black87),
                title: const Text('Comptabilité et revenus', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/poster/comptabilite');
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded, color: Colors.black87),
                title: const Text('Partager le profil', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié dans le presse-papier')));
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrivateStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEA580C))),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.orange.shade800)),
      ],
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, {int lines = 1, TextInputType? type, String? Function(String?)? validator}) {
    return TextFormField(
      controller: c,
      maxLines: lines,
      keyboardType: type,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEA580C), width: 1.5)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: Color(0xFFFFF7ED), body: Center(child: CircularProgressIndicator(color: Color(0xFFEA580C))));
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF7ED),
        appBar: AppBar(title: const Text('Profil'), backgroundColor: const Color(0xFFFFF7ED), foregroundColor: Colors.black),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erreur\n$_error', textAlign: TextAlign.center),
              TextButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    final data = _profile!;
    final username = data['username']?.toString() ?? '';
    final companyName = data['company_name']?.toString() ?? '';
    final bio = data['bio']?.toString() ?? '';
    final website = data['website']?.toString() ?? '';
    final isActive = data['is_active'] == true;
    final totalArticles = data['total_articles']?.toString() ?? '0';
    final publishedArticles = data['published_articles']?.toString() ?? '0';
    final totalViews = data['total_views']?.toString() ?? '0';
    final displayName = companyName.isNotEmpty ? companyName : username;
    final initials = _initials(displayName);
    
    final currentUser = ref.watch(authStateProvider).value;
    final avatarUrl = !_isPublicView ? currentUser?.photoUrl : data['avatar']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7ED),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          displayName,
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          if (!_isPublicView)
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: _openSettingsSheet,
            ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          headerSliverBuilder: (context, _) {
            return [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomCenter,
                      children: [
                        // Banner
                        Container(
                          height: 140,
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFEA580C), Color(0xFFFFEDD5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        // Avatar
                        Positioned(
                          bottom: -48,
                          child: Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(color: const Color(0xFFFFF7ED), width: 4),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
                                  ],
                                ),
                                child: CircleAvatar(
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                                      ? CachedNetworkImageProvider(avatarUrl)
                                      : null,
                                  child: (avatarUrl == null || avatarUrl.isEmpty)
                                      ? Text(
                                          initials,
                                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.black54),
                                        )
                                      : null,
                                ),
                              ),
                              if (!_isPublicView)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _pickAndUploadAvatar,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEA580C),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFFFFF7ED), width: 2),
                                      ),
                                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 56),
                    // @Username
                    Text(
                      '@$username',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
                    ),
                    if (!isActive) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text('Compte suspendu', style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Stats Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStatColumn(totalArticles, 'Articles'),
                        _buildStatDivider(),
                        _buildStatColumn(publishedArticles, 'Publiés'),
                        _buildStatDivider(),
                        _buildStatColumn(totalViews, 'Vues'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isPublicView) ...[
                          _buildButton(
                            text: "S'abonner",
                            color: const Color(0xFFEA580C),
                            textColor: Colors.white,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fonctionnalité à venir')));
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildIconButton(Icons.camera_alt_outlined),
                        ] else ...[
                          _buildButton(
                            text: 'Modifier le profil',
                            color: Colors.grey.shade100,
                            textColor: Colors.black87,
                            onTap: _openEditSheet,
                          ),
                          const SizedBox(width: 8),
                          _buildButton(
                            text: 'Partager le profil',
                            color: Colors.grey.shade100,
                            textColor: Colors.black87,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié')));
                            },
                          ),
                        ]
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Bio
                    if (bio.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          bio,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Link
                    if (website.isNotEmpty) ...[
                      GestureDetector(
                        onTap: () {
                           Clipboard.setData(ClipboardData(text: website));
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié')));
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.link, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              website.length > 30 ? '${website.substring(0, 30)}...' : website,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Tab Bar
                    const Divider(height: 1),
                    TabBar(
                      indicatorColor: Colors.black87,
                      labelColor: Colors.black87,
                      unselectedLabelColor: Colors.grey.shade400,
                      tabs: const [
                        Tab(icon: Icon(Icons.grid_view_rounded)),
                        Tab(icon: Icon(Icons.lock_outline_rounded)),
                      ],
                    ),
                  ],
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              // Tab 1: Articles grid (placeholder)
              (int.tryParse(publishedArticles) ?? 0) > 0
                  ? GridView.builder(
                      padding: const EdgeInsets.all(2),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 2,
                        mainAxisSpacing: 2,
                        childAspectRatio: 0.75, // Format vertical
                      ),
                      itemCount: int.tryParse(publishedArticles) ?? 0,
                      itemBuilder: (context, index) {
                        return Container(
                          color: Colors.grey.shade200,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Center(child: Icon(Icons.article_rounded, color: Colors.grey.shade300, size: 40)),
                              Positioned(
                                bottom: 4,
                                left: 4,
                                child: Row(
                                  children: [
                                    const Icon(Icons.play_arrow_outlined, color: Colors.white, size: 16),
                                    const SizedBox(width: 2),
                                    Text('${(index * 123) + 42}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.article_outlined, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun article publié',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
              // Tab 2: Private (placeholder)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'Contenu privé',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 16,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      color: Colors.grey.shade300,
    );
  }

  Widget _buildButton({required String text, required Color color, required Color textColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.black87, size: 20),
      ),
    );
  }
}
