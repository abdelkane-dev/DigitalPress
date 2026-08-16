import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/abonnement_service.dart';
import '../../model/abonnement.dart';
import '../../widgets/main_app_bar.dart';

/// Remplace la roadmap (fonctionnalité retirée de la plateforme) sur
/// l'onglet principal éditeur : vraie fonctionnalité utile, propre à
/// l'éditeur (l'admin a la sienne, distincte — voir
/// admin_withdrawals_screen.dart) — la liste des lecteurs abonnés à ses
/// offres, avec le plan choisi et la date d'expiration de chacun.
///
/// [embedded=true] : la page est affichée dans les 4 onglets principaux de
/// l'app → son en-tête reprend celui des autres pages principales (logo +
/// titre à gauche, icônes à droite). Sur sa propre route
/// (/poster/subscribers) elle garde son en-tête orange actuel.
class PosterSubscribersScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const PosterSubscribersScreen({super.key, this.embedded = false});

  @override
  ConsumerState<PosterSubscribersScreen> createState() => _PosterSubscribersScreenState();
}

class _PosterSubscribersScreenState extends ConsumerState<PosterSubscribersScreen> {
  static const _orange = Color(0xFFEA580C);

  bool _loading = true;
  List<Abonnement> _subscribers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ref.read(abonnementServiceProvider).getPublisherSubscribers();
      if (mounted) {
        setState(() {
          _subscribers = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Gestion d'un abonné (menu •••) : retirer l'abonné (annulation des
  /// abonnements) ou bannir le lecteur (annulation + suspension du compte).
  Future<void> _manageSubscriber(Abonnement sub, String action) async {
    final isBan = action == 'ban';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isBan ? 'Bannir ce lecteur ?' : 'Retirer cet abonné ?'),
        content: Text(
          isBan
              ? 'Les abonnements de « ${sub.readerUsername} » chez vous seront annulés '
                  'et son compte lecteur sera suspendu définitivement.'
              : 'Les abonnements de « ${sub.readerUsername} » chez vous seront annulés. '
                  'Il pourra se réabonner plus tard s\'il le souhaite.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isBan ? Colors.red : _orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isBan ? 'Bannir' : 'Retirer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final service = ref.read(abonnementServiceProvider);
      if (isBan) {
        await service.banSubscriber(sub.readerId);
      } else {
        await service.cancelSubscriber(sub.readerId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBan
                ? 'Abonné banni (abonnements annulés, compte suspendu).'
                : 'Abonné retiré (abonnements annulés).',
          ),
          backgroundColor: isBan ? Colors.red : Colors.green,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCard(Abonnement sub) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _orange.withAlpha(30),
            child: Text(
              sub.readerUsername.isNotEmpty ? sub.readerUsername[0].toUpperCase() : '?',
              style: const TextStyle(color: _orange, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sub.readerUsername,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(sub.planName ?? 'Plan',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                if (sub.endDate != null)
                  Text(
                    'jusqu\'au ${sub.endDate!.day.toString().padLeft(2, '0')}/${sub.endDate!.month.toString().padLeft(2, '0')}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5),
                  ),
              ],
            ),
          ),
          // ─── GESTION DE L'ABONNÉ (demande explicite) ─────────────────
          PopupMenuButton<String>(
            tooltip: 'Gérer cet abonné',
            icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade600),
            onSelected: (value) => _manageSubscriber(sub, value),
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'cancel',
                child: Row(
                  children: [
                    Icon(Icons.person_remove_rounded, color: Color(0xFFEA580C), size: 20),
                    SizedBox(width: 10),
                    Text('Retirer l\'abonné', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'ban',
                child: Row(
                  children: [
                    Icon(Icons.block_rounded, color: Colors.red, size: 20),
                    SizedBox(width: 10),
                    Text('Bannir le lecteur',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ─── Mode intégré (onglets principaux) : en-tête comme les autres
    // pages principales (MainAppBar), contenu en CustomScrollView.
    if (widget.embedded) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Pas de logo sur cet onglet (demande explicite) — titre seul,
            // bien mis en évidence, comme sur les autres pages principales.
            MainAppBar(title: 'mes abonnés'),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: _orange)),
              )
            else if (_subscribers.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      "Aucun abonné pour le moment. Dès qu'un lecteur souscrit à l'une de vos offres, il apparaîtra ici.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildCard(_subscribers[index]),
                    ),
                    childCount: _subscribers.length,
                  ),
                ),
              ),
            // Espace pour ne pas masquer la dernière carte sous la barre
            // de navigation principale.
            const SliverToBoxAdapter(child: SizedBox(height: 140)),
          ],
        ),
      );
    }

    // ─── Mode route dédiée : en-tête orange actuel (inchangé). ─────────
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _orange,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Mes abonnés (${_subscribers.length})',
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 20)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : _subscribers.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      "Aucun abonné pour le moment. Dès qu'un lecteur souscrit à l'une de vos offres, il apparaîtra ici.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _orange,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _subscribers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _buildCard(_subscribers[index]),
                  ),
                ),
    );
  }
}
