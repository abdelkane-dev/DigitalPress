import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/auth_service.dart';
import '../../model/user.dart';
import 'package:go_router/go_router.dart';
import 'edit_profile_screen.dart';
import 'purchase_history_screen.dart';
import 'change_password_screen.dart';
import '../notifications/notifications_screen.dart';
import '../../widgets/notification_bell_button.dart';
import '../../widgets/main_app_bar.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final userAsync = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('Non connecté'));
          return CustomScrollView(
            slivers: [
              const MainAppBar(title: 'Profil'),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildProfileHeader(context, ref, user),
                    _buildStatsCards(user),
                    _buildMenuSection(context, authService, ref, user),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erreur: $err')),
      ),
    );
  }

  Future<void> _pickAndUploadImage(BuildContext context, WidgetRef ref) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mise à jour de la photo de profil...')),
          );
        }
        await ref.read(authServiceProvider).updateProfile(avatarFile: image);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo de profil mise à jour avec succès'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildProfileHeader(BuildContext context, WidgetRef ref, User user) {
    ImageProvider? imageProvider;
    if (user.photoUrl != null) {
      if (user.photoUrl!.startsWith('http') || kIsWeb) {
        imageProvider = NetworkImage(user.photoUrl!);
      } else {
        imageProvider = FileImage(File(user.photoUrl!));
      }
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A2647), Color(0xFF144272)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2647).withAlpha(60),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: () => _pickAndUploadImage(context, ref),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber.shade300, width: 3),
                    gradient: imageProvider == null
                        ? const LinearGradient(
                            colors: [Color(0xFF2C74B3), Color(0xFF4CA1AF)],
                          )
                        : null,
                    image: imageProvider != null
                        ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(50),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: imageProvider == null
                      ? const Icon(
                          Icons.person_rounded,
                          size: 50,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade400,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0A2647), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(40),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 18,
                      color: Color(0xFF0A2647),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            user.displayName ?? 'Utilisateur',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            user.email,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (user.phoneNumber != null) ...[
            const SizedBox(height: 4),
            Text(
              user.phoneNumber!,
              style: const TextStyle(fontSize: 14, color: Colors.white60),
            ),
          ],
          if (user.isVerified) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade300.withAlpha(30),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.shade300.withAlpha(100)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_rounded,
                    color: Colors.amber.shade300,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Membre Premium',
                    style: TextStyle(
                      color: Colors.amber.shade300,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsCards(User user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.shopping_bag_rounded,
              label: 'Achats',
              value: '${user.stats.totalPurchases}',
              color: const Color(0xFF2C74B3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.auto_stories_rounded,
              label: 'Lectures',
              value: '${user.stats.totalReads}',
              color: const Color(0xFF10B981),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.bookmark_rounded,
              label: 'Favoris',
              value: '${user.stats.totalBookmarks}',
              color: const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withAlpha(50), color.withAlpha(10)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(
    BuildContext context,
    AuthService authService,
    WidgetRef ref,
    User user,
  ) {
    return Column(
      children: [
        const SizedBox(height: 16),
        _buildMenuGroup(
          title: 'Général',
          children: [
            _buildMenuItem(
              icon: Icons.person_outline_rounded,
              title: 'Informations personnelles',
              subtitle: 'Gérer vos informations',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
              },
            ),
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.receipt_long_rounded,
              title: 'Historique d\'achats',
              subtitle: 'Voir vos transactions',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PurchaseHistoryScreen(),
                  ),
                );
              },
            ),
            if (user.role == 'reader') ...[
              _buildDivider(),
              _buildMenuItem(
                icon: Icons.account_balance_wallet_rounded,
                title: 'Mon Portefeuille',
                subtitle: 'Solde, recharges et transactions',
                onTap: () => context.push('/profile/wallet'),
              ),
            ],
            if (user.role == 'publisher') ...[
              _buildDivider(),
              _buildMenuItem(
                icon: Icons.account_balance_rounded,
                title: 'Comptabilité Presse',
                subtitle: 'Solde, revenus et retraits',
                onTap: () => context.push('/poster/comptabilite'),
              ),
            ],
            if (user.role == 'admin') ...[
              _buildDivider(),
              _buildMenuItem(
                icon: Icons.admin_panel_settings_rounded,
                title: 'Comptabilité Générale',
                subtitle: 'Journal général et réconciliations',
                onTap: () => context.push('/admin/comptabilite'),
              ),
            ],
          ],
        ),
        _buildMenuGroup(
          title: 'Paramètres',
          children: [
            _buildMenuItem(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Gérer les alertes',
              trailing: Switch(
                value: true, // Mock value
                onChanged: (val) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Notifications ${val ? "activées" : "désactivées"}'),
                    ),
                  );
                },
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF336B82),
              ),
              onTap: () {},
            ),
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.security_rounded,
              title: 'Sécurité',
              subtitle: 'Changer le mot de passe',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                );
              },
            ),
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.help_outline_rounded,
              title: 'Aide et support',
              subtitle: 'FAQ, contact',
              onTap: () {
                _showHelpDialog(context);
              },
            ),
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.info_outline_rounded,
              title: 'À propos',
              subtitle: 'Version 1.0.0',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'DigitalPress',
                  applicationVersion: '1.0.0',
                  applicationIcon: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/app_icon.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  children: const [
                    Text('La meilleure application de presse numérique.'),
                  ],
                );
              },
            ),
          ],
        ),
        _buildMenuGroup(
          title: 'Compte',
          children: [
            _buildMenuItem(
              icon: Icons.logout_rounded,
              title: 'Déconnexion',
              subtitle: 'Se déconnecter du compte',
              color: Colors.red.shade600,
              onTap: () {
                _showLogoutDialog(context, authService);
              },
            ),
          ],
        ),
        const SizedBox(height: 100), // Espace supplémentaire pour le scroll / BottomNavBar
      ],
    );
  }

  Widget _buildMenuGroup({required String title, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
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
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
    Widget? trailing,
  }) {
    final itemColor = color ?? Colors.black87;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: itemColor.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: itemColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: itemColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: Colors.grey.shade200),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Déconnexion',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir vous déconnecter ?',
          style: TextStyle(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              authService.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Déconnexion',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Aide et Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pour toute assistance, contactez-nous :'),
            SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.email, size: 16),
                SizedBox(width: 8),
                Text('support@digitalpress.com'),
              ],
            ),
            SizedBox(height: 5),
            Row(
              children: [
                Icon(Icons.phone, size: 16),
                SizedBox(width: 8),
                Text('+223 70 00 00 00'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}
