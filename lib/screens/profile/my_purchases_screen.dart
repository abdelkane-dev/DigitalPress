import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/services/app_notification_service.dart';
import '../../core/services/abonnement_service.dart';
import '../../config/api_constants.dart';
import '../../model/abonnement.dart';

/// « Mes achats » (note Dr. Sissoko) : un seul écran couvrant la liste des
/// ACHATS SIMPLES (publications achetées à l'unité) ET les ABONNEMENTS
/// (liste des éditeurs auxquels le lecteur est abonné), via deux onglets.
/// Remplace l'ancien « Historique d'achats » et l'ancien bouton d'abonnements
/// séparé : tout se retrouve au même endroit, accessible depuis le bouton
/// « Mes achats » de la page profil.
class MyPurchasesScreen extends ConsumerStatefulWidget {
  const MyPurchasesScreen({super.key});

  @override
  ConsumerState<MyPurchasesScreen> createState() => _MyPurchasesScreenState();
}

class _MyPurchasesScreenState extends ConsumerState<MyPurchasesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _loadingPurchases = true;
  List<dynamic> _purchases = [];

  bool _loadingSubscriptions = true;
  List<Abonnement> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPurchases();
    _loadSubscriptions();
    ref.listenManual(realtimeEventProvider, (previous, next) {
      if (next != null) {
        _loadPurchases();
        _loadSubscriptions();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPurchases() async {
    setState(() => _loadingPurchases = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(ApiConstants.mesTransactions);
      List<dynamic> items = [];
      if (res.statusCode == 200 && res.data != null) {
        if (res.data is List) {
          items = res.data as List;
        } else if (res.data is Map && res.data['results'] != null) {
          items = res.data['results'] as List;
        }
      }
      if (mounted) {
        setState(() {
          // Achats simples uniquement (les abonnements sont dans le 2e onglet).
          _purchases = items
              .where((tx) => tx['type_transaction'] == 'purchase')
              .toList();
        });
      }
    } catch (_) {
      // Liste indisponible : on affiche l'état vide.
    } finally {
      if (mounted) setState(() => _loadingPurchases = false);
    }
  }

  Future<void> _loadSubscriptions() async {
    setState(() => _loadingSubscriptions = true);
    try {
      final list =
          await ref.read(abonnementServiceProvider).getMyAbonnements();
      if (mounted) {
        setState(() {
          _subscriptions = list.where((a) => a.isActive).toList();
        });
      }
    } catch (_) {
      // Liste indisponible : on affiche l'état vide.
    } finally {
      if (mounted) setState(() => _loadingSubscriptions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2647),
        title: const Text(
          'Mes achats',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFF59E0B),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long_rounded, size: 20), text: 'Achats'),
            Tab(
              icon: Icon(Icons.subscriptions_rounded, size: 20),
              text: 'Abonnements',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPurchasesTab(),
          _buildSubscriptionsTab(),
        ],
      ),
    );
  }

  // ─── ONGLET 1 : ACHATS SIMPLES ─────────────────────────────────────────
  Widget _buildPurchasesTab() {
    if (_loadingPurchases) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_purchases.isEmpty) {
      return _buildEmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'Aucun achat pour l\u2019instant',
        subtitle: 'Vos achats simples de publications apparaîtront ici.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPurchases,
      color: const Color(0xFF2C74B3),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _purchases.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final tx = _purchases[index] as Map<String, dynamic>;
          return _buildPurchaseCard(tx);
        },
      ),
    );
  }

  Widget _buildPurchaseCard(Map<String, dynamic> tx) {
    final amount =
        double.tryParse(tx['montant_brut']?.toString() ?? '0') ?? 0.0;
    final status = tx['status'] as String? ?? 'pending';
    final title = tx['publication_title'] as String? ?? 'Achat';
    final dateStr = tx['created_at'] != null
        ? _formatDate(DateTime.tryParse(tx['created_at'].toString()))
        : '';

    final (statusColor, statusLabel, statusIcon) = switch (status) {
      'success' => (Colors.green, 'Réussi', Icons.check_circle_rounded),
      'failed' => (Colors.red, 'Échoué', Icons.cancel_rounded),
      'cancelled' => (Colors.orange, 'Annulé', Icons.cancel_outlined),
      _ => (Colors.blue, 'En attente', Icons.hourglass_empty_rounded),
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2C74B3).withAlpha(25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: Color(0xFF2C74B3),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF0A2647),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            dateStr,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 13, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(
                                fontSize: 12,
                                color: statusColor,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '-${amount.toStringAsFixed(0)} FCFA',
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

  // ─── ONGLET 2 : ABONNEMENTS (liste des éditeurs) ────────────────────────
  Widget _buildSubscriptionsTab() {
    if (_loadingSubscriptions) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_subscriptions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.subscriptions_rounded,
        title: 'Aucun abonnement actif',
        subtitle:
            'Les éditeurs auxquels vous êtes abonné apparaîtront ici.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadSubscriptions,
      color: const Color(0xFF2C74B3),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _subscriptions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final sub = _subscriptions[index];
          return _buildPublisherCard(sub);
        },
      ),
    );
  }

  Widget _buildPublisherCard(Abonnement sub) {
    final name = sub.publisherName ?? 'Éditeur';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: const Color(0xFF0A2647).withAlpha(30),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Color(0xFF0A2647),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          sub.planName?.isNotEmpty == true
              ? 'Offre « ${sub.planName} »'
              : 'Abonnement actif',
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: Color(0xFF2C74B3)),
        onTap: sub.publisherId == null
            ? null
            : () => context.push('/publisher/${sub.publisherId}'),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF2C74B3).withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: const Color(0xFF2C74B3)),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0A2647),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    const months = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc',
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}
