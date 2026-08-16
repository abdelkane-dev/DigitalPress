import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/auth_service.dart';

/// Écran affiché uniquement quand PublisherProfile.is_active == false, ce
/// qui ne peut désormais arriver que si un administrateur a suspendu le
/// compte : l'accès plateforme est gratuit et automatique dès la création
/// du compte éditeur (aucun paiement, aucun abonnement à choisir — voir
/// apps.abonnements.services.sync_publisher_tier côté backend).
///
/// Palette alignée sur le reste de l'espace éditeur (orange — voir
/// poster_dashboard_screen.dart).
class PosterSubscribeScreen extends ConsumerWidget {
  const PosterSubscribeScreen({super.key});

  static const _orange = Color(0xFFEA580C);
  static const _bg = Color(0xFFFFF7ED);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _orange,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Compte suspendu',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.3, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.pause_circle_rounded, color: _orange, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Votre compte a été suspendu',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF7C2D12)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              "L'accès à la plateforme est automatique pour tout éditeur — "
              "aucun abonnement ni paiement n'est jamais requis. Si vous voyez cet écran, "
              "c'est qu'un administrateur a suspendu votre compte. Contactez le support "
              "pour en connaître la raison et demander sa réactivation.",
              style: TextStyle(color: Colors.black54, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
