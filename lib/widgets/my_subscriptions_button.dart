import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/services/abonnement_service.dart';
import '../model/abonnement.dart';

/// Bouton en haut à droite du profil lecteur (dans MainAppBar.extraAction) :
/// accès rapide aux comptes éditeur auxquels le lecteur est abonné, façon
/// liste "Abonnements" de TikTok/Instagram. N'affiche que les abonnements
/// (pas les achats — déjà couverts par l'historique de transactions, pas
/// les lectures récentes — non demandé au final), pour ne pas faire double
/// emploi avec le reste de la page profil.
class MySubscriptionsButton extends StatelessWidget {
  const MySubscriptionsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Mes abonnements',
      icon: const Icon(Icons.subscriptions_outlined, color: Colors.white),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) => const _MySubscriptionsSheet(),
        );
      },
    );
  }
}

class _MySubscriptionsSheet extends ConsumerStatefulWidget {
  const _MySubscriptionsSheet();

  @override
  ConsumerState<_MySubscriptionsSheet> createState() => _MySubscriptionsSheetState();
}

class _MySubscriptionsSheetState extends ConsumerState<_MySubscriptionsSheet> {
  bool _loading = true;
  List<Abonnement> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ref.read(abonnementServiceProvider).getMyAbonnements();
      if (mounted) {
        setState(() {
          _subscriptions = list.where((a) => a.isActive).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mes abonnements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${_subscriptions.length} compte(s) suivi(s)',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _subscriptions.isEmpty
                      ? const Center(
                          child: Text(
                            "Vous n'êtes abonné à aucun compte pour le moment.",
                            style: TextStyle(color: Colors.black54),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: _subscriptions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final sub = _subscriptions[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF0A2647).withAlpha(30),
                                child: Text(
                                  (sub.publisherName?.isNotEmpty ?? false)
                                      ? sub.publisherName![0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(color: Color(0xFF0A2647), fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(sub.publisherName ?? 'Éditeur', overflow: TextOverflow.ellipsis),
                              subtitle: Text(sub.planName ?? '', overflow: TextOverflow.ellipsis),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: sub.publisherId == null
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      context.push('/publisher/${sub.publisherId}');
                                    },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
