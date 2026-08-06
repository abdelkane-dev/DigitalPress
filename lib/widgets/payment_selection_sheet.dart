import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/services/payment_service.dart';
import '../screens/payment/payment_screen.dart';

/// Fenêtre de sélection du mode de paiement (BottomSheet).
class PaymentSelectionSheet extends ConsumerWidget {
  final String journalId;
  final double price;
  final bool isSubscribed;
  final bool isRecharge;
  final bool isSubscription;
  final bool isResellRight;
  final int? abonnementId;
  final String? journalTitle;
  final VoidCallback? onPaymentSuccess;

  const PaymentSelectionSheet({
    super.key,
    required this.journalId,
    this.price = 0,
    this.isSubscribed = false,
    this.isRecharge = false,
    this.isSubscription = false,
    this.isResellRight = false,
    this.abonnementId,
    this.journalTitle,
    this.onPaymentSuccess,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              // --- MODE DE TEST ---
              _buildPaymentOption(
                context,
                ref,
                title: 'Simulation (Test)',
                subtitle: 'Paiement fictif pour tester (Immédiat)',
                icon: Icons.bug_report_rounded,
                color: Colors.green.shade600,
                type: PaymentMethodType.simulation,
              ),
              const SizedBox(height: 12),
              // Mode de paiement Portefeuille
              _buildPaymentOption(
                context,
                ref,
                title: 'Mon Portefeuille',
                subtitle: 'Payer avec votre solde disponible',
                icon: Icons.account_balance_wallet_rounded,
                color: const Color(0xFF0A2647),
                type: PaymentMethodType.wallet,
              ),
              const SizedBox(height: 12),
              _buildPaymentOption(
                context,
                ref,
                title: 'Wave',
                subtitle: 'Rapide et sans frais',
                icon: Icons.water_drop_rounded,
                color: const Color(0xFF49B8E7),
                type: PaymentMethodType.wave,
              ),
              const SizedBox(height: 12),
              _buildPaymentOption(
                context,
                ref,
                title: 'Orange Money',
                subtitle: 'Simple et sécurisé',
                icon: Icons.payments_rounded,
                color: const Color(0xFFFF7900),
                type: PaymentMethodType.orangeMoney,
              ),
              const SizedBox(height: 12),
              _buildPaymentOption(
                context,
                ref,
                title: 'Moov Money',
                subtitle: 'Paiement mobile Moov',
                icon: Icons.phone_android_rounded,
                color: const Color(0xFF003399),
                type: PaymentMethodType.moovMoney,
              ),
              const SizedBox(height: 12),
              _buildPaymentOption(
                context,
                ref,
                title: 'Carte Bancaire',
                subtitle: 'Visa, Mastercard, etc.',
                icon: Icons.credit_card_rounded,
                color: const Color(0xFF635BFF),
                type: PaymentMethodType.stripe,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final title = isRecharge ? 'Recharger mon compte' : 'Mode de paiement';
    final subtitle = isRecharge
        ? 'Choisissez comment alimenter votre portefeuille'
        : 'Total à payer : ${price.toStringAsFixed(0)} FCFA';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close_rounded, color: Colors.grey.shade400),
        ),
      ],
    );
  }

  Widget _buildPaymentOption(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required PaymentMethodType type,
  }) {
    // Cacher le portefeuille si c'est une recharge (évite la récursion)
    if (isRecharge && type == PaymentMethodType.wallet) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () {
        Navigator.pop(context); // Ferme le BottomSheet
        // Navigation vers la page de paiement (mobile money / carte / portefeuille)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentScreen(
              journalId: journalId,
              journalTitle: journalTitle ?? 'Journal #$journalId',
              price: price,
              paymentMethod: type,
              paymentMethodName: title,
              abonnementId: abonnementId,
              isSubscription: isSubscription,
              isResellRight: isResellRight,
              isRecharge: isRecharge,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }
}

/// Fonction utilitaire pour afficher la sélection.
/// Si [isSubscribed] ou [price] == 0 → ouvre directement le lecteur.
Future<void> showPaymentSelection(
  BuildContext context,
  String journalId,
  double price, {
  bool isSubscribed = false,
}) {
  // Accès direct si abonné ou contenu gratuit
  if (isSubscribed || price == 0) {
    context.push('/reader/$journalId', extra: isSubscribed);
    return Future.value();
  }

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => PaymentSelectionSheet(
      journalId: journalId,
      price: price,
      isSubscribed: isSubscribed,
    ),
  );
}
