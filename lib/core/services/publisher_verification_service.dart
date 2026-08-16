import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../api/api_client.dart';

/// Étape 1/3 (éditeur) et 2/3 (admin) de l'onboarding éditeur :
/// vérification de légitimité avant tout accès à la plateforme.
/// Voir aussi publisher_subscription_service.dart pour l'étape 3/3.
class PublisherVerificationService {
  final ApiClient _apiClient;
  final Logger _logger = Logger();

  PublisherVerificationService(this._apiClient);

  /// Statut de MA vérification (côté éditeur connecté). null si jamais soumise.
  Future<Map<String, dynamic>?> getMyVerification() async {
    try {
      final response = await _apiClient.get('accounts/me/verification/');
      return response.data['verification'] as Map<String, dynamic>?;
    } catch (e) {
      _logger.e('Erreur statut vérification : $e');
      rethrow;
    }
  }

  /// Soumet (ou re-soumet après rejet) le formulaire de vérification.
  Future<Map<String, dynamic>> submit(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post('accounts/me/verification/', data: data);
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      _logger.e('Erreur soumission vérification : $e');
      rethrow;
    }
  }

  /// [Admin] Liste des dossiers de vérification, filtrable par statut.
  Future<List<Map<String, dynamic>>> adminListVerifications({String? status}) async {
    try {
      final response = await _apiClient.get(
        'accounts/admin/verifications/',
        queryParameters: status != null ? {'status': status} : null,
      );
      final data = response.data;
      final results = data is Map ? data['results'] ?? data : data;
      return List<Map<String, dynamic>>.from(results as List);
    } catch (e) {
      _logger.e('Erreur liste vérifications admin : $e');
      rethrow;
    }
  }

  /// [Admin] Approuve ou rejette un dossier (déclenche notif + email éditeur).
  Future<void> adminReview(int verificationId, {required bool approve, String? rejectionReason}) async {
    try {
      await _apiClient.post(
        'accounts/admin/verifications/$verificationId/review/',
        data: {
          'decision': approve ? 'approved' : 'rejected',
          if (rejectionReason != null) 'rejection_reason': rejectionReason,
        },
      );
    } catch (e) {
      _logger.e('Erreur revue vérification admin : $e');
      rethrow;
    }
  }
}

final publisherVerificationServiceProvider = Provider<PublisherVerificationService>((ref) {
  return PublisherVerificationService(ref.watch(apiClientProvider));
});
