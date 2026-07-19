import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/services/auth_service.dart';
import '../../model/user.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Champs communs
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  // Champs éditeur
  late TextEditingController _companyController;
  late TextEditingController _siretController;
  late TextEditingController _addressController;
  late TextEditingController _websiteController;
  late TextEditingController _bioController;

  bool _isLoading = false;
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = ref.read(authServiceProvider).currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
    _companyController = TextEditingController(text: user?.companyName ?? '');
    _siretController = TextEditingController(text: user?.siret ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
    _websiteController = TextEditingController(text: user?.website ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _siretController.dispose();
    _addressController.dispose();
    _websiteController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _showImageSourceActionSheet(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF0A2647)),
              title: const Text('Galerie'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImageFromSource(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0A2647)),
              title: const Text('Appareil photo'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImageFromSource(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _imageFile = image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sélection : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authServiceProvider).currentUser;
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        avatarFile: _imageFile,
        companyName: user?.isPublisher == true ? _companyController.text.trim() : null,
        siret: user?.isPublisher == true ? _siretController.text.trim() : null,
        address: user?.isPublisher == true ? _addressController.text.trim() : null,
        website: user?.isPublisher == true ? _websiteController.text.trim() : null,
        bio: user?.isPublisher == true ? _bioController.text.trim() : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour ✓'), backgroundColor: Colors.green),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authStateProvider);
    final user = userAsync.valueOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2647),
        title: const Text(
          'Informations personnelles',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(user),
              const SizedBox(height: 28),

              // ── Badge rôle ──────────────────────────────────────────────
              if (user != null) _buildRoleBadge(user),
              const SizedBox(height: 24),

              // ── Informations de base ─────────────────────────────────────
              _buildSectionTitle('Informations de base', Icons.person_outline_rounded),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _nameController,
                label: 'Nom complet',
                icon: Icons.badge_rounded,
                validator: (v) => v!.isEmpty ? 'Nom requis' : null,
              ),
              const SizedBox(height: 16),
              if (user != null) _buildReadOnlyField('Email', user.email, Icons.email_rounded),
              const SizedBox(height: 16),
              if (user != null) _buildReadOnlyField('Nom d\'utilisateur', '@${user.username}', Icons.alternate_email_rounded),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _phoneController,
                label: 'Téléphone',
                icon: Icons.phone_android_rounded,
                keyboardType: TextInputType.phone,
                validator: (v) => v!.isEmpty ? 'Téléphone requis' : null,
              ),

              // ── Champs spécifiques Éditeur ───────────────────────────────
              if (user?.isPublisher == true) ...[
                const SizedBox(height: 28),
                _buildSectionTitle('Profil de presse', Icons.newspaper_rounded),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _companyController,
                  label: 'Nom de l\'entreprise / Journal',
                  icon: Icons.business_rounded,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _siretController,
                  label: 'SIRET / Numéro d\'enregistrement',
                  icon: Icons.pin_rounded,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _addressController,
                  label: 'Adresse',
                  icon: Icons.location_on_rounded,
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _websiteController,
                  label: 'Site web',
                  icon: Icons.language_rounded,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _bioController,
                  label: 'Biographie / Description',
                  icon: Icons.info_outline_rounded,
                  maxLines: 4,
                ),
              ],

              // ── Champs spécifiques Admin ─────────────────────────────────
              if (user?.isAdmin == true) ...[
                const SizedBox(height: 28),
                _buildSectionTitle('Administration', Icons.admin_panel_settings_rounded),
                const SizedBox(height: 12),
                _buildReadOnlyField('Rôle système', 'Administrateur Principal', Icons.security_rounded),
                const SizedBox(height: 16),
                _buildReadOnlyField('Accès', 'Toutes les fonctionnalités', Icons.lock_open_rounded),
              ],

              const SizedBox(height: 36),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(User user) {
    final (label, color, icon) = switch (user.role) {
      'admin' => ('Administrateur', const Color(0xFFEF4444), Icons.admin_panel_settings_rounded),
      'publisher' => ('Éditeur / Presse', const Color(0xFF8B5CF6), Icons.newspaper_rounded),
      _ => ('Lecteur', const Color(0xFF2C74B3), Icons.auto_stories_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(width: 8),
          if (user.isVerified)
            Icon(Icons.verified_rounded, color: color, size: 18),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF0A2647), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0A2647),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey.shade500),
        title: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0A2647))),
      ),
    );
  }

  Widget _buildAvatar(User? user) {
    ImageProvider? imageProvider;
    if (_imageFile != null) {
      if (kIsWeb) {
        imageProvider = NetworkImage(_imageFile!.path);
      } else {
        imageProvider = FileImage(File(_imageFile!.path));
      }
    } else if (user?.photoUrl != null && user!.photoUrl!.isNotEmpty) {
      imageProvider = user.photoUrl!.startsWith('http')
          ? NetworkImage(user.photoUrl!) as ImageProvider
          : NetworkImage(user.photoUrl!); // Fix for non-absolute URLs on web
    }

    return Center(
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: imageProvider == null
                  ? const LinearGradient(colors: [Color(0xFF0A2647), Color(0xFF2C74B3)])
                  : null,
              image: imageProvider != null
                  ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                  : null,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: imageProvider == null
                ? const Icon(Icons.person_rounded, size: 60, color: Colors.white)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => _showImageSourceActionSheet(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C74B3),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(Icons.camera_alt_rounded, size: 20, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF2C74B3)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF2C74B3), width: 2)),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0A2647),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
        child: _isLoading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : const Text('Enregistrer les modifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
