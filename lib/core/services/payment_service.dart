import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api_client.dart';
import 'package:logger/logger.dart';

/// Les différents types de paiement supportés.
enum PaymentMethodType {
  wallet, // Portefeuille interne
  wave,
  orangeMoney,
  moovMoney,
  samaMoney,
  stripe, // Carte bancaire
}

/// Modèle pour une session de paiement initiée par le backend.
class PaymentSession {
  final String reference;
  final String paymentUrl;
  final String status;

  PaymentSession({
    required this.reference,
    required this.paymentUrl,
    required this.status,
  });

  factory PaymentSession.fromJson(Map<String, dynamic> json) {
    final tx = json['transaction'] as Map<String, dynamic>?;
    return PaymentSession(
      reference: tx != null ? (tx['reference'] ?? '') : (json['reference'] ?? ''),
      paymentUrl: json['payment_url'] as String? ?? '',
      status: tx != null ? (tx['status'] ?? 'pending') : (json['status'] ?? 'pending'),
    );
  }
}

/// Fournisseur pour le service de paiement.
final paymentServiceProvider = Provider<PaymentService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PaymentService(apiClient);
});

/// Service gérant les transactions financières via Stripe et Mobile Money (Mali).
class PaymentService {
  final ApiClient _apiClient;
  final _logger = Logger();

  PaymentService(this._apiClient);

  /// Initie un paiement pour une publication ou un abonnement spécifique.
  Future<PaymentSession?> initiatePayment({
    String? publicationId,
    int? abonnementId,
    required String phone,
    required double amount,
    required PaymentMethodType method,
    bool isSubscription = false,
  }) async {
    try {
      final Map<String, dynamic> requestData = {
        'phone': phone,
        'montant': amount,
        'type_transaction': isSubscription ? 'subscription' : 'purchase',
        'mode_paiement': method == PaymentMethodType.wallet ? 'wallet' : 'movapay',
      };

      if (publicationId != null) {
        requestData['publication_id'] = publicationId;
      }
      if (abonnementId != null) {
        requestData['abonnement_id'] = abonnementId;
      }

      final response = await _apiClient.post(
        'paiements/initier/',
        data: requestData,
      );

      final session = PaymentSession.fromJson(response.data);
      _logger.i('Session de paiement créée avec référence : ${session.reference}');

      // Si un lien de redirection de paiement est fourni, on tente de l'ouvrir
      if (session.paymentUrl.isNotEmpty) {
        await _launchPaymentUrl(session.paymentUrl);
      }

      return session;
    } catch (e) {
      _logger.e('Erreur lors de l\'initiation du paiement : $e');
      rethrow;
    }
  }

  /// Ouvre l'URL de paiement dans le navigateur externe ou l'application dédiée.
  Future<bool> _launchPaymentUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      _logger.i('Lancement de l\'URL de paiement : $url');
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _logger.e('Impossible d\'ouvrir l\'URL de paiement : $url');
      return false;
    }
  }

  /// Vérifie le statut d'une transaction.
  Future<String> checkPaymentStatus(String reference) async {
    try {
      final response = await _apiClient.post(
        'paiements/verifier/',
        data: {'reference': reference},
      );
      final tx = response.data['transaction'];
      final status = tx != null ? tx['status'] : response.data['status'];
      return status?.toString() ?? 'pending';
    } catch (e) {
      _logger.e('Erreur lors de la vérification du statut : $e');
      return 'error';
    }
  }

  /// Attend la finalisation du paiement en vérifiant le statut périodiquement.
  Future<bool> waitForPaymentCompletion(
    String reference, {
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < timeout) {
      try {
        final status = await checkPaymentStatus(reference);

        if (status == 'success' || status == 'completed' || status == 'paid') {
          _logger.i('Paiement confirmé pour la référence $reference');
          return true;
        } else if (status == 'failed' || status == 'cancelled') {
          _logger.w('Paiement échoué ou annulé pour la référence $reference');
          return false;
        }

        // Attendre 3 secondes avant la prochaine vérification
        await Future.delayed(const Duration(seconds: 3));
      } catch (e) {
        _logger.w('Erreur temporaire lors du polling : $e');
        await Future.delayed(const Duration(seconds: 5));
      }
    }

    _logger.w('Timeout lors de l\'attente du paiement $reference');
    return false;
  }
}
