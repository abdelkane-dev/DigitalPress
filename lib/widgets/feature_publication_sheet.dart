import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/publication_service.dart';
import '../model/publication.dart';

/// Prix de la mise en avant (FCFA) par durée — miroir de FEATURED_PRICES
/// côté backend (backend/apps/publications/views.py).
const Map<int, int> kFeaturedPrices = {
  7: 5000,
  14: 8000,
  30: 12000,
};

/// Moyens de paiement de la mise en avant — MÊMES que ceux des lecteurs
/// (système unifié : l'ancien choix "simulation/movapay" propre aux
/// éditeurs/admins a été supprimé définitivement). Le wallet paie
/// immédiatement ; les autres passent par CinetPay (mobile money ou
/// carte), en mode simulation tant que les clés marchand ne sont pas
/// renseignées.
class _FeaturePaymentMethod {
  final String mode;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _FeaturePaymentMethod({
    required this.mode,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

const List<_FeaturePaymentMethod> _featureMethods = [
  _FeaturePaymentMethod(
    mode: 'wallet',
    label: 'Mon Portefeuille',
    subtitle: 'Payé immédiatement depuis votre solde de revenus',
    icon: Icons.account_balance_wallet_rounded,
    color: Color(0xFF0A2647),
  ),
  _FeaturePaymentMethod(
    mode: 'wave',
    label: 'Wave',
    subtitle: 'Rapide et sécurisé',
    icon: Icons.water_drop_rounded,
    color: Color(0xFF49B8E7),
  ),
  _FeaturePaymentMethod(
    mode: 'orange_money',
    label: 'Orange Money',
    subtitle: 'Simple et sécurisé',
    icon: Icons.payments_rounded,
    color: Color(0xFFFF7900),
  ),
  _FeaturePaymentMethod(
    mode: 'moov_money',
    label: 'Moov Money',
    subtitle: 'Paiement mobile Moov',
    icon: Icons.phone_android_rounded,
    color: Color(0xFF003399),
  ),
  _FeaturePaymentMethod(
    mode: 'card',
    label: 'Carte Bancaire',
    subtitle: 'Visa, Mastercard — CinetPay',
    icon: Icons.credit_card_rounded,
    color: Color(0xFF635BFF),
  ),
];

/// Feuille « Mettre à la une » (espace éditeur) : l'éditeur paie pour mettre
/// sa publication en avant sur l'accueil pendant 7, 14 ou 30 jours, façon
/// publicité Facebook. Paiement depuis le solde d'éditeur (wallet) ou en
/// mobile money simulé.
Future<void> showFeaturePublicationSheet(
  BuildContext context,
  WidgetRef ref,
  Publication publication,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FeaturePublicationSheet(publication: publication),
  );
}

class FeaturePublicationSheet extends ConsumerStatefulWidget {
  final Publication publication;

  const FeaturePublicationSheet({super.key, required this.publication});

  @override
  ConsumerState<FeaturePublicationSheet> createState() =>
      _FeaturePublicationSheetState();
}

class _FeaturePublicationSheetState
    extends ConsumerState<FeaturePublicationSheet> {
  int _days = 7;
  String _mode = 'wallet';
  bool _isLoading = false;
  String _phone = '';

  String get _price => '${kFeaturedPrices[_days]} FCFA';

  Future<void> _pay() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(publicationServiceProvider);
      final result = await service.featurePublication(
        widget.publication.id,
        days: _days,
        mode: _mode,
        phone: _phone,
      );

      // Mobile money / carte (CinetPay, simulation tant que pas de clés
      // réelles) : on vérifie le paiement — le mock sandbox confirme
      // immédiatement ; en réel le webhook + la vérification côté serveur
      // font foi. En mode portefeuille, la promotion est déjà active.
      if (_mode != 'wallet') {
        final reference = result['transaction']?.toString() ?? '';
        if (reference.isNotEmpty) {
          await service.verifyFeaturePayment(widget.publication.id, reference);
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Votre publication est maintenant À LA UNE sur l\'accueil ✓',
            ),
            backgroundColor: Colors.green,
          ),
        );
        ref
            .read(publisherPublicationsListProvider.notifier)
            .loadMyPublications();
        ref.invalidate(featuredProvider);
        ref.read(publicationListProvider.notifier).load(refresh: true);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $msg'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF0A2647),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      color: Color(0xFFFFB703), size: 28),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Mettre À LA UNE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '« ${widget.publication.title} »',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Votre publication apparaîtra en tête de la section À LA UNE '
                'de l\'accueil, pendant la durée choisie — comme une publicité.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),

              // Durée
              const Text(
                'Durée de mise en avant',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: kFeaturedPrices.entries.map((entry) {
                  final selected = _days == entry.key;
                  return ChoiceChip(
                    selected: selected,
                    label: Text('${entry.key} jours'),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    selectedColor: const Color(0xFFFFB703),
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    checkmarkColor: Colors.white,
                    onSelected: (_) => setState(() => _days = entry.key),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),

              // Moyen de paiement — les MÊMES que pour les lecteurs.
              const Text(
                'Moyen de paiement',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              ..._featureMethods.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _modeOption(
                      value: m.mode,
                      icon: m.icon,
                      title: m.label,
                      subtitle: m.subtitle,
                      color: m.color,
                    ),
                  )),
              if (_mode != 'wallet') ...[
                const SizedBox(height: 4),
                TextField(
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Numéro de téléphone (mobile money)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: '+223 70 00 00 00',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.phone_rounded,
                        color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: Colors.white, width: 1.4),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                  ),
                  onChanged: (v) => _phone = v.trim(),
                ),
              ],

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pay,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.rocket_launch_rounded),
                  label: Text(
                    _isLoading
                        ? 'Traitement…'
                        : 'Mettre à la une — $_price',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB703),
                    foregroundColor: const Color(0xFF0A2647),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Paiement sécurisé. La mise en avant s\'arrête '
                'automatiquement à la fin de la période.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeOption({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final selected = _mode == value;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _mode = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFB703).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFFFFB703) : Colors.white24,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: selected ? const Color(0xFFFFB703) : color,
                  size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? const Color(0xFFFFB703) : Colors.white38,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
