import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../api/api_client.dart';

/// Gère le PALIER (Basique/Standard/Premium) de l'éditeur sur la plateforme
/// — un système d'avantages, PAS un abonnement payant (distinct de
/// abonnement_service.dart, qui gère lui le vrai abonnement payant
/// LECTEUR -> ÉDITEUR).
///
/// Flux : un admin crée le compte éditeur (accès immédiat et gratuit,
/// PublisherProfile.is_active=True dès la création) -> l'éditeur démarre au
/// palier "Basique" -> il progresse automatiquement vers "Standard" puis
/// "Premium" selon son nombre d'abonnés, de publications et de ventes (voir
/// apps.abonnements.services.sync_publisher_tier côté backend). Aucune
/// action ni paiement n'est requis de sa part.
class PublisherSubscriptionService {
  final ApiClient _apiClient;
  final Logger _logger = Logger();

  PublisherSubscriptionService(this._apiClient);

  /// Liste des paliers plateforme (Basique/Standard/Premium) et leurs
  /// avantages respectifs.
  Future<List<Map<String, dynamic>>> getPlatformPlans() async {
    try {
      final response = await _apiClient.get('abonnements/platform-plans/');
      final data = response.data;
      final results = data is Map ? data['results'] ?? data : data;
      return List<Map<String, dynamic>>.from(results as List);
    } catch (e) {
      _logger.e('Erreur chargement paliers plateforme : $e');
      rethrow;
    }
  }

  /// Palier actuel de l'éditeur connecté + sa progression vers le palier
  /// suivant. Retourne {'subscription': {...} | null, 'has_access': bool,
  /// 'progression': {'abonnes', 'publications', 'ventes', 'palier_suivant'}}.
  Future<Map<String, dynamic>> getMySubscriptionStatus() async {
    try {
      final response = await _apiClient.get('abonnements/platform-subscription/me/');
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      _logger.e('Erreur statut palier plateforme : $e');
      rethrow;
    }
  }
}

final publisherSubscriptionServiceProvider = Provider<PublisherSubscriptionService>((ref) {
  return PublisherSubscriptionService(ref.watch(apiClientProvider));
});
