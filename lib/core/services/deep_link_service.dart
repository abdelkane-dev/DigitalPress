import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fournisseur pour le service de gestion des liens profonds (Deep Links).
final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  return const DeepLinkService();
});

/// Service chargé d'analyser les URLs entrantes pour naviguer vers un contenu précis
/// ou déclencher une action.
class DeepLinkService {
  const DeepLinkService();

  /// Traite une URL entrante.
  void handleDeepLink(BuildContext context, Uri uri) async {
    // 1. Détection des liens (ex: confirmation ou autre)
    // Note: Retiré car spécifique à Firebase Auth.

    // 2. Retour de paiement (Deep Link)
    // Scheme attendu: digitalpress://payment/callback?status=success&session_id=xyz
    if (uri.pathSegments.contains('payment') &&
        uri.pathSegments.contains('callback')) {
      final status = uri.queryParameters['status'];
      final sessionId = uri.queryParameters['session_id'];

      if (status == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paiement réussi ! Votre contenu est débloqué.'),
            backgroundColor: Colors.green,
          ),
        );
        // Ici on pourrait rafraîchir le profil ou les droits d'accès
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Paiement échoué ou annulé. Session: $sessionId'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // 3. Navigation classique vers un journal
    if (uri.pathSegments.contains('journal')) {
      final journalId = uri.queryParameters['id'];
      if (journalId != null) {
        context.push('/reader/$journalId');
      }
    }
  }
}
