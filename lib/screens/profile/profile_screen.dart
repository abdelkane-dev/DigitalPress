import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/auth_service.dart';
import '../../model/user.dart';
import 'package:go_router/go_router.dart';
import 'edit_profile_screen.dart';
import 'purchase_history_screen.dart';
import 'change_password_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final userAsync = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('Non connecté'));
          return CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildProfileHeader(user),
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

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 100.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF0A2647),
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: const Text(
          'Profil',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A2647), Color(0xFF144272)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(User user) {
    ImageProvider? imageProvider;
    if (user.photoUrl != null) {
      if (user.photoUrl!.startsWith('http')) {
        imageProvider = NetworkImage(user.photoUrl!);
      } else {
        imageProvider = FileImage(File(user.photoUrl!));
      }
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2647).withAlpha(8),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: imageProvider == null
                  ? const LinearGradient(
                      colors: [Color(0xFF0A2647), Color(0xFF2C74B3)],
                    )
                  : null,
              image: imageProvider != null
                  ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2C74B3).withAlpha(80),
                  blurRadius: 20,
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
          const SizedBox(height: 16),
          Text(
            user.displayName ?? 'Utilisateur',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0A2647),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (user.phoneNumber != null) ...[
            const SizedBox(height: 4),
            Text(
              user.phoneNumber!,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
          const SizedBox(height: 16),
          _buildRoleBadge(user),
          const SizedBox(height: 16),
          if (user.isVerified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2C74B3).withAlpha(25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF2C74B3),
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Compte Vérifié',
                    style: TextStyle(
                      color: Color(0xFF2C74B3),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(User user) {
    final (label, color, icon) = switch (user.role) {
      'admin' => (
          'Administrateur',
          const Color(0xFFEF4444),
          Icons.admin_panel_settings_rounded
        ),
      'publisher' => (
          'Éditeur / Presse',
          const Color(0xFF8B5CF6),
          Icons.newspaper_rounded
        ),
      _ => ('Lecteur', const Color(0xFF2C74B3), Icons.auto_stories_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 14),
          ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2647).withAlpha(8),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
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
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2647).withAlpha(8),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
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
          _buildDivider(),
          if (user.role == 'reader') ...[
            _buildMenuItem(
              icon: Icons.account_balance_wallet_rounded,
              title: 'Mon Portefeuille',
              subtitle: 'Solde, recharges et transactions',
              onTap: () => context.push('/profile/wallet'),
            ),
            _buildDivider(),
          ],
          if (user.role == 'publisher') ...[
            _buildMenuItem(
              icon: Icons.account_balance_rounded,
              title: 'Comptabilité Presse',
              subtitle: 'Solde, revenus et retraits',
              onTap: () => context.push('/poster/comptabilite'),
            ),
            _buildDivider(),
          ],
          if (user.role == 'admin') ...[
            _buildMenuItem(
              icon: Icons.admin_panel_settings_rounded,
              title: 'Comptabilité Générale',
              subtitle: 'Journal général et réconciliations',
              onTap: () => context.push('/admin/comptabilite'),
            ),
            _buildDivider(),
          ],
          _buildMenuItem(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Gérer les notifications',
            trailing: Switch(
              value: true, // Mock value
              onChanged: (val) {
                // Mock toggle
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Notifications ${val ? "activées" : "désactivées"}',
                    ),
                  ),
                );
              },
              activeThumbColor: const Color(0xFF2C74B3),
            ),
            onTap: () {}, // No action on tap, handled by switch
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
                applicationIcon: const Icon(
                  Icons.menu_book_rounded,
                  size: 50,
                  color: Color(0xFF0A2647),
                ),
                children: [
                  const Text('La meilleure application de presse numérique.'),
                ],
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.logout_rounded,
            title: 'Déconnexion',
            subtitle: 'Se déconnecter du compte',
            color: Colors.red,
            onTap: () {
              _showLogoutDialog(context, authService);
            },
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
    final itemColor = color ?? const Color(0xFF0A2647);

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Déconnexion',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF0A2647),
          ),
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir vous déconnecter ?',
          style: TextStyle(fontSize: 14),
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
