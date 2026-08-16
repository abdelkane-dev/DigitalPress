import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/auth_service.dart';
import '../core/storage/storage_service.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/profile/my_purchases_screen.dart';
import '../widgets/notification_bell_button.dart';

/// En-tête commun des 4 pages principales (Accueil, Abonnés/Catégories,
/// Discussions, Profil) — « toujours dans la même idée » quel que soit le
/// type d'utilisateur :
///
///  • Ligne 1 : logo + nom « DigitalPress » collés à gauche et mis en
///    évidence ; les 3 icônes (vue grille/liste, cloche, avatar) sur la
///    même ligne mais collées à droite et plus petites.
///  • Accueil uniquement ([showWelcome]) : en-tête agrandi avec le logo et
///    le nom plus en avant, puis sur la ligne suivante le message de
///    bienvenue — « Bienvenue » à la toute première connexion, « Bon
///    retour » ensuite (mémorisé par utilisateur dans le stockage local).
///  • Les autres pages : logo + titre toujours collés à gauche, bien mis
///    en évidence, sans message de bienvenue.
class MainAppBar extends ConsumerStatefulWidget {
  final String title;
  final bool showLogo;

  /// Accueil uniquement : affiche « Bienvenue » / « Bon retour » sur une
  /// seconde ligne (première connexion vs connexions suivantes).
  final bool showWelcome;

  /// Accueil : en-tête agrandi (logo + nom plus grands, plus en avant).
  final bool enlarged;

  final Widget? extraAction;
  final Widget? titleBadge;

  const MainAppBar({
    super.key,
    required this.title,
    this.showLogo = false,
    this.showWelcome = false,
    this.enlarged = false,
    this.extraAction,
    this.titleBadge,
  });

  @override
  ConsumerState<MainAppBar> createState() => _MainAppBarState();
}

class _MainAppBarState extends ConsumerState<MainAppBar> {
  /// Clé de stockage local indiquant si l'utilisateur a déjà été accueilli
  /// (pour distinguer première connexion → « Bienvenue » des connexions
  /// suivantes → « Bon retour »). Clé par utilisateur pour ne jamais
  /// mélanger deux comptes sur le même appareil.
  static String _welcomeKey(String userId) => 'welcome_greeted_$userId';

  /// ─── TITRES EN MAJUSCULE (demande explicite) ──────────────────────────
  /// « profil », « conversations », « mes abonnés »… commençaient par une
  /// minuscule selon la page qui appelait l'entête. Toute première lettre
  /// est désormais capitalisée ici, une fois pour toutes les pages :
  /// Profil, Conversations, Mes abonnés…
  static String _capitalize(String title) {
    if (title.isEmpty) return title;
    return title[0].toUpperCase() + title.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authStateProvider);
    final user = userAsync.valueOrNull;
    final firstName = (user?.displayName?.isNotEmpty == true)
        ? user!.displayName!.split(' ').first
        : null;

    final isEnlarged = widget.enlarged;
    final toolbarHeight = isEnlarged ? 116.0 : 84.0;
    final logoSize = isEnlarged ? 44.0 : 28.0;
    final titleSize = isEnlarged ? 24.0 : 21.0;
    // Icônes plus petites, partout — sur l'accueil elles étaient trop
    // grosses (demande explicite), les autres pages suivent la même taille.
    final iconSize = 22.0;
    final avatarSize = 32.0;

    return SliverAppBar(
      toolbarHeight: toolbarHeight,
      expandedHeight: toolbarHeight,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF0A2647),
      titleSpacing: 16,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo + nom collés à gauche (ligne 1)
          if (widget.showLogo) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/app_icon.png',
                width: logoSize,
                height: logoSize,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _capitalize(widget.title),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: titleSize,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    if (widget.titleBadge != null) ...[
                      const SizedBox(width: 6),
                      widget.titleBadge!,
                    ],
                  ],
                ),
                // ─── ACCUEIL : message de bienvenue / bon retour ────────
                // Uniquement sur l'accueil (demande explicite), sur la ligne
                // suivante sous le logo + nom. « Bienvenue » à la première
                // connexion, « Bon retour » ensuite.
                if (widget.showWelcome && firstName != null)
                  FutureBuilder<String>(
                    future: _welcomeMessage(firstName, user),
                    builder: (context, snapshot) {
                      final message = snapshot.data ?? 'Bienvenue, $firstName 👋';
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          message,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withAlpha(210),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Les 3 icônes : vue grille/liste, cloche, avatar — sur la même
        // ligne que le logo, collées à droite, plus petites.
        if (widget.extraAction != null) widget.extraAction!,
        Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: NotificationBellButton(
            color: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
          ),
        ),
        // ─── AVATAR PROFIL : MENU D'ACTIONS RAPIDES ─────────────────────
        // (demande explicite) : le tap sur l'avatar de l'ENTÊTE affiche un
        // petit menu d'actions rapides (2 actions : Mes achats / Déconnexion)
        // au lieu d'ouvrir directement la page profil — la page profil reste
        // accessible via l'onglet normal du pied de page.
        GestureDetector(
          onTap: () => _showHeaderQuickMenu(context),
          child: Container(
            margin: const EdgeInsets.only(right: 14),
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              image: (user?.photoUrl != null && user!.photoUrl!.isNotEmpty)
                  ? DecorationImage(
                      image: NetworkImage(user.photoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: const Color(0xFF2C74B3),
            ),
            child: (user?.photoUrl == null || user!.photoUrl!.isEmpty)
                ? Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: iconSize * 0.55,
                  )
                : null,
          ),
        ),
      ],
    );
  }

  /// Petit menu d'actions rapides affiché au tap sur l'avatar de l'en-tête
  /// (demande explicite : "le bouton profil ne doit renvoyer nulle part
  /// mais afficher un petit menu avec quelques boutons d'action rapide comme
  /// la déconnexion, 3 actions max"). L'entrée « profil » a été retirée du
  /// menu : la page profil s'ouvre via l'onglet du pied de page.
  void _showHeaderQuickMenu(BuildContext context) {
    final size = MediaQuery.of(context).size;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        size.width - 220,
        120,
        size.width - 8,
        220,
      ),
      color: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      items: [
        PopupMenuItem(
          value: 'purchases',
          height: 52,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shopping_bag_rounded,
                    color: Color(0xFF10B981), size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Mes achats',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: Color(0xFF0A2647))),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'logout',
          height: 52,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout_rounded,
                    color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Déconnexion',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: Colors.red)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null || !context.mounted) return;
      switch (value) {
        case 'purchases':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyPurchasesScreen()),
          );
        case 'logout':
          _showLogoutConfirm(context);
      }
    });
  }

  void _showLogoutConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Déconnexion',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black87)),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?',
            style: TextStyle(fontSize: 14, color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler',
                style: TextStyle(
                    color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authServiceProvider).signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Déconnexion',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// Détermine « Bienvenue » (première connexion) ou « Bon retour »
  /// (connexions suivantes) pour l'utilisateur connecté.
  Future<String> _welcomeMessage(String firstName, dynamic user) async {
    final userId = user?.id?.toString() ?? 'anonymous';
    try {
      final storage = ref.read(storageServiceProvider);
      final key = _welcomeKey(userId);
      final alreadyGreeted = storage.get(key, defaultValue: false) == true;
      if (!alreadyGreeted) {
        await storage.set(key, true);
      }
      return alreadyGreeted
          ? 'Bon retour, $firstName 👋'
          : 'Bienvenue, $firstName 👋';
    } catch (_) {
      // Stockage indisponible : on affiche le message générique de bienvenue.
      return 'Bienvenue, $firstName 👋';
    }
  }
}
