import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/abonnement_service.dart';
import '../../core/services/publication_service.dart';
import '../../core/utils/friendly_error.dart';
import '../../model/publication.dart';
import '../../model/abonnement.dart';
import '../../widgets/payment_selection_sheet.dart';

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
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _websiteController = TextEditingController();
  final _addressController = TextEditingController();
  final _siretController = TextEditingController();
  final _bioController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic>? _profile;

  List<Publication> _articles = [];
  bool _loadingArticles = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
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
      _usernameController.text = data['username']?.toString() ?? '';
      _nameController.text =
          ref.read(authServiceProvider).currentUser?.displayName ?? data['company_name']?.toString() ?? '';
      _companyController.text = data['company_name']?.toString() ?? '';
      _websiteController.text = data['website']?.toString() ?? '';
      _addressController.text = data['address']?.toString() ?? '';
      _siretController.text = data['siret']?.toString() ?? '';
      _bioController.text = data['bio']?.toString() ?? '';
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    // Les articles publiés se chargent séparément (endpoint public
    // PublicationListView?publisher_id=X, déjà filtré status='published')
    // pour ne jamais bloquer l'affichage du profil si ça échoue.
    unawaited(_loadArticles());
  }

  Future<void> _loadArticles() async {
    // widget.publisherId (vue publique) est un User.id ; en vue "soi-même"
    // (widget.publisherId == null), _profile['id'] est l'id du
    // PublisherProfile (PAS le même id !) — il faut l'id User réel de
    // l'utilisateur connecté, sinon la liste d'articles serait toujours
    // vide côté éditeur consultant son propre profil.
    final id = widget.publisherId ??
        int.tryParse(ref.read(authServiceProvider).currentUser?.id ?? '');
    if (id == null) return;
    setState(() => _loadingArticles = true);
    try {
      final articles = await ref
          .read(publicationServiceProvider)
          .getPublications(publisherId: id);
      if (mounted) setState(() => _articles = articles);
    } catch (_) {
      // Silencieux : la grille affichera simplement "aucun article".
    } finally {
      if (mounted) setState(() => _loadingArticles = false);
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
      // @username + nom complet : champs du compte User (pas du profil
      // éditeur) — mis à jour via /accounts/me/ pour un contrôle TikTok
      // complet (nom, @username, bio, avatar, couverture...).
      final authService = ref.read(authServiceProvider);
      final user = authService.currentUser;
      final usernameChanged = _usernameController.text.trim().isNotEmpty &&
          _usernameController.text.trim() != (user?.username ?? '');
      final nameChanged = _nameController.text.trim() != (user?.displayName ?? '');
      if (usernameChanged || nameChanged) {
        await authService.updateProfile(
          username: usernameChanged ? _usernameController.text.trim() : null,
          name: nameChanged ? _nameController.text.trim() : null,
        );
      }
      if (mounted) {
        Navigator.pop(context); // Fermer le bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour avec succès.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo de profil mise à jour avec succès!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    }
  }

  /// Change la couverture/bannière de la page publique (façon TikTok) :
  /// l'image est uploadée sur PublisherProfile.cover_image via
  /// authService.updateProfile(coverFile: ...).
  Future<void> _pickAndUploadCover() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (xfile == null) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mise à jour de la couverture en cours...')),
      );
    }

    try {
      final authService = ref.read(authServiceProvider);
      await authService.updateProfile(coverFile: xfile);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couverture mise à jour avec succès!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
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
                      _field(
                        _usernameController,
                        '@username (identifiant public)',
                        Icons.alternate_email_rounded,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Champ requis';
                          if (!RegExp(r'^[a-zA-Z0-9_]{3,30}$').hasMatch(v.trim())) {
                            return '3 à 30 caractères : lettres, chiffres, _';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _field(_nameController, 'Nom complet', Icons.person_outline_rounded),
                      const SizedBox(height: 14),
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
              // Partage du profil retiré : rien ne doit sortir de l'app
              // (demande explicite anti-partage).
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
    final coverImage = data['cover_image']?.toString() ?? '';
    final isActive = data['is_active'] == true;
    final hasVerifiedBadge = data['has_verified_badge'] == true;
    final publishedArticles = data['published_articles']?.toString() ?? '0';
    final totalViews = data['total_views']?.toString() ?? '0';
    final subscriberCount = data['subscriber_count']?.toString() ?? '0';
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                displayName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            if (hasVerifiedBadge) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified_rounded, color: Color(0xFF2563EB), size: 18),
            ],
          ],
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
                        // Banner / Couverture (image modifiable, façon TikTok)
                        SizedBox(
                          height: 140,
                          width: double.infinity,
                          child: coverImage.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: coverImage,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFFEA580C), Color(0xFFFFEDD5)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFFEA580C), Color(0xFFFFEDD5)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                  ),
                                )
                              : const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFFEA580C), Color(0xFFFFEDD5)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                ),
                        ),
                        // Bouton de modification de la couverture (self-view)
                        if (!_isPublicView)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: _pickAndUploadCover,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.photo_camera_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
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
                    // ─── NOM + @username (design retravaillé) ─────────────
                    // Le nom de l'entreprise s'affiche en évidence sous
                    // l'avatar (le @username reste le sous-titre), comme sur
                    // les profils créateur : hiérarchie visuelle claire.
                    Text(
                      displayName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.alternate_email_rounded,
                            size: 15, color: Colors.grey),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            username,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54),
                          ),
                        ),
                        if (hasVerifiedBadge) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded,
                              color: Color(0xFF2563EB), size: 18),
                        ],
                      ],
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
                    // Stats Row — Publiés / Vues / Abonnés : 3 métriques
                    // distinctes et utiles pour un visiteur (l'ancien
                    // "Articles" faisait doublon avec "Publiés" et n'était
                    // de toute façon jamais renvoyé par l'API).
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(child: _buildStatColumn(publishedArticles, 'Publiés')),
                        _buildStatDivider(),
                        Flexible(child: _buildStatColumn(totalViews, 'Vues')),
                        _buildStatDivider(),
                        Flexible(child: _buildStatColumn(subscriberCount, 'Abonnés')),
                      ],
                    ),
                    // ─── BANNIÈRE COMMISSION SUPPRIMÉE (demande explicite) ─
                    // « % Commission plateforme : 20.0% • Palier Basique » :
                    // cette information interne n'a rien à faire sur le profil
                    // (publique ou personnel) — elle ne concerne que la
                    // comptabilité éditeur. Supprimée définitivement de cette
                    // page (la commission reste visible dans « Comptabilité
                    // Presse » où elle a du sens).
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
                            onTap: _openSubscribeSheet,
                          ),
                          if ((website).isNotEmpty) ...[
                            const SizedBox(width: 8),
                            _buildIconButton(
                              Icons.language_rounded,
                              onTap: () => _launchWebsite(website),
                            ),
                          ],
                        ] else ...[
                          _buildButton(
                            text: 'Modifier le profil',
                            color: const Color(0xFFEA580C),
                            textColor: Colors.white,
                            onTap: _openEditSheet,
                          ),
                          const SizedBox(width: 8),
                          // Bouton « Partager le profil » retiré : rien ne
                          // doit sortir de l'app (demande explicite).
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
                    // Tab Bar (libellés ajoutés : Publications / Exclusif)
                    const Divider(height: 1),
                    TabBar(
                      indicatorColor: const Color(0xFFEA580C),
                      labelColor: const Color(0xFFEA580C),
                      unselectedLabelColor: Colors.grey.shade500,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.grid_view_rounded, size: 20),
                          text: 'Publications',
                        ),
                        Tab(
                          icon: Icon(Icons.lock_outline_rounded, size: 20),
                          text: 'Exclusif',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              // Tab 1: vrais articles publiés (remplace l'ancienne grille de
              // vignettes factices avec des compteurs de vues aléatoires).
              _loadingArticles
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFEA580C)))
                  : _articles.isNotEmpty
                      ? GridView.builder(
                          padding: const EdgeInsets.all(2),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: _articles.length,
                          itemBuilder: (context, index) {
                            final article = _articles[index];
                            return InkWell(
                              onTap: () => context.push('/reader/${article.id}'),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  article.coverImage.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: article.coverImage,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              Container(color: Colors.grey.shade200),
                                          errorWidget: (context, url, error) => Container(
                                            color: Colors.grey.shade200,
                                            child: Icon(Icons.article_rounded,
                                                color: Colors.grey.shade400, size: 32),
                                          ),
                                        )
                                      : Container(
                                          color: Colors.grey.shade200,
                                          child: Icon(Icons.article_rounded,
                                              color: Colors.grey.shade400, size: 32),
                                        ),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.fromLTRB(6, 12, 6, 4),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withAlpha(160),
                                          ],
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.visibility_rounded,
                                              color: Colors.white, size: 14),
                                          const SizedBox(width: 3),
                                          Flexible(
                                            child: Text(
                                              '${article.viewsCount}',
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
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
              // Tab 2 : contenu réservé aux abonnés — mêmes vignettes que
              // l'onglet 1, filtrées sur isSubscriberExclusive, avec un
              // cadenas superposé tant que le lecteur n'est pas abonné à
              // ce compte (article.isSubscribed, calculé par le backend
              // via Publication.is_accessible_by).
              Builder(builder: (context) {
                final exclusiveArticles =
                    _articles.where((a) => a.isSubscriberExclusive).toList();
                if (_loadingArticles) {
                  return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFEA580C)));
                }
                if (exclusiveArticles.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          "Aucun contenu exclusif pour l'instant",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: exclusiveArticles.length,
                  itemBuilder: (context, index) {
                    final article = exclusiveArticles[index];
                    final locked = !article.isSubscribed;
                    return InkWell(
                      onTap: () => context.push('/reader/${article.id}'),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          article.coverImage.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: article.coverImage,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      Container(color: Colors.grey.shade200),
                                  errorWidget: (context, url, error) => Container(
                                    color: Colors.grey.shade200,
                                    child: Icon(Icons.article_rounded,
                                        color: Colors.grey.shade400, size: 32),
                                  ),
                                )
                              : Container(
                                  color: Colors.grey.shade200,
                                  child: Icon(Icons.article_rounded,
                                      color: Colors.grey.shade400, size: 32),
                                ),
                          if (locked)
                            Container(
                              color: Colors.black.withAlpha(140),
                              child: const Center(
                                child: Icon(Icons.lock_rounded, color: Colors.white, size: 28),
                              ),
                            ),
                          Positioned(
                            bottom: 4,
                            left: 4,
                            right: 4,
                            child: Text(
                              article.title,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 16,
      width: 1,
      // 24px de marge de chaque côté (48px total x2 diviseurs) dépassait
      // la largeur de l'écran sur téléphone étroit avec 3 colonnes de
      // stats — d'où le débordement horizontal signalé sur cet écran.
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.grey.shade300,
    );
  }

  Widget _buildButton({required String text, required Color color, required Color textColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (color != Colors.grey.shade100)
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
    );
  }

  Future<void> _launchWebsite(String website) async {
    var url = website.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir ce lien.")),
      );
    }
  }

  /// Le bouton "S'abonner" ne faisait rien avant ce correctif (juste un
  /// SnackBar "Fonctionnalité à venir"). Flux complet maintenant : liste
  /// des plans de CET éditeur -> choix -> création de l'abonnement
  /// (status='pending') -> paiement via la feuille de paiement déjà
  /// utilisée partout ailleurs dans l'app.
  Future<void> _openSubscribeSheet() async {
    final publisherId = widget.publisherId;
    if (publisherId == null) return;

    List<AbonnementPlan> plans;
    try {
      plans = await ref.read(abonnementServiceProvider).getPlansForPublisher(publisherId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible de charger les offres d'abonnement.")),
      );
      return;
    }

    if (!mounted) return;
    if (plans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cet éditeur ne propose pas d'abonnement pour le moment.")),
      );
      return;
    }

    final chosen = await showModalBottomSheet<AbonnementPlan>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Choisissez une offre",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              ...plans.map((plan) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    elevation: 0,
                    child: ListTile(
                      title: Text(plan.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${plan.prix.toStringAsFixed(0)} F / ${plan.periodLabel}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).pop(plan),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );

    if (chosen == null || !mounted) return;

    try {
      final abonnement = await ref.read(abonnementServiceProvider).createAbonnement(chosen.id);
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => PaymentSelectionSheet(
          journalId: 'plan-${chosen.id}',
          journalTitle: "Abonnement — ${chosen.name}",
          price: chosen.prix,
          isSubscription: true,
          abonnementId: abonnement.id,
        ),
      );
      if (mounted) await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible de créer l'abonnement.")),
      );
    }
  }

  Widget _buildIconButton(IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {},
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
