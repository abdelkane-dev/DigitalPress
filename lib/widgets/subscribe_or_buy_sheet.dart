import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/services/abonnement_service.dart';
import '../core/services/auth_service.dart';
import '../../model/models.dart';
import 'payment_selection_sheet.dart';

/// BottomSheet premium pour choisir entre achat unitaire et abonnement à la presse.
class SubscribeOrBuySheet extends ConsumerStatefulWidget {
  final Publication publication;

  const SubscribeOrBuySheet({
    super.key,
    required this.publication,
  });

  @override
  ConsumerState<SubscribeOrBuySheet> createState() => _SubscribeOrBuySheetState();
}

class _SubscribeOrBuySheetState extends ConsumerState<SubscribeOrBuySheet> {
  bool _isCreatingAbonnement = false;

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(publisherPlansProvider(widget.publication.publisherId));
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 32, 24, bottomPadding > 0 ? bottomPadding + 16 : 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildJournalPreview(),
              const SizedBox(height: 24),
              const Text(
                'Choisissez votre formule',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A2647),
                ),
              ),
              const SizedBox(height: 12),
              // Option Achat Unitaire (les droits de revente ont été
              // retirés de la plateforme : c'est soit on achète, soit on
              // s'abonne — aucune autre option d'accès).
              _buildUnitOption(),
              const SizedBox(height: 12),
              // Options Abonnements
              plansAsync.when(
                data: (plans) {
                  if (plans.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Aucun plan d\'abonnement disponible pour cette presse.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    );
                  }
                  return Column(
                    children: plans.map((plan) => _buildPlanOption(plan)).toList(),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(color: Color(0xFF2C74B3)),
                  ),
                ),
                error: (err, stack) => Text('Erreur chargement plans: $err'),
              ),
              if (_isCreatingAbonnement)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF2C74B3)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Accéder au contenu',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0A2647),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Choisissez l\'achat unitaire ou un abonnement',
                style: TextStyle(fontSize: 13, color: Colors.grey),
                softWrap: true,
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

  Widget _buildJournalPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              widget.publication.coverImage,
              width: 50,
              height: 65,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 50,
                height: 65,
                color: Colors.grey.shade200,
                child: const Icon(Icons.image, size: 24, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.publication.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF0A2647),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.publication.subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Publié par : ${widget.publication.publisherName}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C74B3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitOption() {
    return InkWell(
      onTap: () {
        Navigator.pop(context); // Ferme ce sheet
        // Ouvre le sheet de paiement
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => PaymentSelectionSheet(
            journalId: widget.publication.id.toString(),
            price: widget.publication.prix,
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2C74B3).withAlpha(50), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2C74B3).withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_bag_rounded, color: Color(0xFF2C74B3)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Acheter ce journal',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF0A2647),
                    ),
                  ),
                  Text(
                    'Accès permanent à ce journal uniquement',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ),
            ),
            Text(
              '${widget.publication.prix.toStringAsFixed(0)} FCFA',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Color(0xFF0A2647),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanOption(AbonnementPlan plan) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InkWell(
        onTap: () => _handleSubscribe(plan),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50.withAlpha(200),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.star_rounded, color: Colors.amber.shade700),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF0A2647),
                      ),
                    ),
                    Text(
                      plan.description.isNotEmpty
                          ? plan.description
                          : 'Accès illimité à toutes les publications de cette presse',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${plan.prix.toStringAsFixed(0)} FCFA',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFF0A2647),
                    ),
                  ),
                  Text(
                    '/${plan.periodLabel}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubscribe(AbonnementPlan plan) async {
    if (_isCreatingAbonnement) return;
    setState(() {
      _isCreatingAbonnement = true;
    });

    try {
      final service = ref.read(abonnementServiceProvider);
      // 1. Créer l'abonnement 'pending' sur le backend
      final abonnement = await service.createAbonnement(plan.id);

      if (!mounted) return;
      Navigator.pop(context); // Ferme ce sheet de sélection

      // 2. Ouvre le sheet de sélection du mode de paiement
      //    en passant l'abonnementId et le flag isSubscription
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => PaymentSelectionSheet(
          journalId: widget.publication.id.toString(),
          journalTitle: plan.name,
          price: plan.prix,
          isSubscription: true,
          abonnementId: abonnement.id,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingAbonnement = false;
        });
      }
    }
  }
}

/// Affiche le menu de sélection achat/abonnement.
void showSubscribeOrBuySelection(BuildContext context, WidgetRef ref, Publication publication) {
  final user = ref.read(authServiceProvider).currentUser;
  final isOwner = user != null && user.id == publication.publisherId.toString();
  final isAdmin = user != null && user.isAdmin;

  if (publication.isSubscribed || publication.prix == 0 || isOwner || isAdmin) {
    // Rediriger directement vers le lecteur
    context.push('/reader/${publication.id}', extra: true);
    return;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SubscribeOrBuySheet(publication: publication),
  );
}
