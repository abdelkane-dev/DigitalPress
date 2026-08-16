import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/publisher_subscription_service.dart';

/// Affiche le PALIER plateforme en cours de l'éditeur (Basique / Standard /
/// Premium) et sa progression vers le palier suivant. Il n'y a plus rien à
/// payer ni à choisir : le palier évolue tout seul selon l'activité de
/// l'éditeur (nombre d'abonnés, de publications, de ventes) — voir
/// apps.abonnements.services.sync_publisher_tier côté backend.
///
/// Design 2026 : carte dégradée navy→bleu, barres de progression arrondies
/// avec % , tuiles de paliers avec l'état « actuel » mis en évidence.
class PosterMySubscriptionScreen extends ConsumerStatefulWidget {
  const PosterMySubscriptionScreen({super.key});

  @override
  ConsumerState<PosterMySubscriptionScreen> createState() => _PosterMySubscriptionScreenState();
}

class _PosterMySubscriptionScreenState extends ConsumerState<PosterMySubscriptionScreen> {
  // Charte graphique DigitalPress (identique au reste de l'app).
  static const _orange = Color(0xFFEA580C);
  static const _navy = Color(0xFF0A2647);
  static const _blue = Color(0xFF2C74B3);
  static const _sky = Color(0xFF56B4E9);
  static const _bg = Color(0xFFF8FAFC);

  bool _loading = true;
  Map<String, dynamic>? _subscription;
  Map<String, dynamic>? _progression;
  List<Map<String, dynamic>> _plans = [];

  /// Convertit une valeur numérique du backend en [double] sans jamais
  /// planter. Le backend Django sérialise les champs Decimal en CHAÎNES
  /// (ex: `'20.00'`, `'15000.00'`) : un cast direct `as num` lève alors une
  /// TypeError qui faisait planter toute la page « Mon palier » (liste des
  /// paliers vide / page blanche).
  static double _toNum(Object? value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // ─── CORRECTIF : les deux requêtes sont indépendantes. Si le statut du
    // palier échoue (ex: compte non approuvé), les paliers eux-mêmes
    // (endpoint public) doivent quand même s'afficher — la page « Mon
    // niveau » ne doit plus jamais rester vide.
    Map<String, dynamic>? status;
    try {
      status =
          await ref.read(publisherSubscriptionServiceProvider).getMySubscriptionStatus();
    } catch (_) {
      // Statut indisponible : on affichera « Palier en cours de calcul… ».
    }
    List<Map<String, dynamic>> plans = [];
    try {
      plans = await ref.read(publisherSubscriptionServiceProvider).getPlatformPlans();
    } catch (_) {
      // Paliers indisponibles : la page affichera les cartes déjà chargées.
    }
    if (!mounted) return;
    setState(() {
      _subscription = status?['subscription'] as Map<String, dynamic>?;
      _progression = status?['progression'] as Map<String, dynamic>?;
      _plans = plans;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _orange,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Mon palier',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3, fontSize: 20)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : RefreshIndicator(
              onRefresh: _load,
              color: _orange,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildCurrentStatusCard(),
                  if (_progression != null) ...[
                    const SizedBox(height: 16),
                    _buildProgressionCard(),
                  ],
                  const SizedBox(height: 28),
                  const Text('Tous les paliers',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _navy)),
                  const SizedBox(height: 4),
                  const Text(
                    "Sans engagement : la plateforme se rémunère uniquement via "
                    "une commission sur vos ventes. Votre palier progresse automatiquement "
                    "selon votre activité.",
                    style: TextStyle(color: Colors.black54, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  ..._plans.map(_buildPlanTile),
                ],
              ),
            ),
    );
  }

  // ─── Carte dégradée du palier actuel ─────────────────────────────────
  Widget _buildCurrentStatusCard() {
    final sub = _subscription;
    if (sub == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_navy, _blue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Text("Palier en cours de calcul…",
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
      );
    }
    final planDetails = sub['plan_details'] as Map<String, dynamic>?;
    final planName = sub['plan_name']?.toString() ?? planDetails?['name']?.toString() ?? 'Basique';
    // commission_rate arrive en chaîne ('20.00') : on le formate sans
    // planter, en supprimant les zéros inutiles (20.00 → 20).
    final rawCommission = _toNum(planDetails?['commission_rate'], -1);
    final commission = rawCommission >= 0
        ? (rawCommission == rawCommission.roundToDouble()
            ? rawCommission.toStringAsFixed(0)
            : rawCommission.toString())
        : '—';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [_navy, Color(0xFF2C74B3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Halo décoratif (cercles translucides) pour un rendu moderne.
          Positioned(
            right: -30,
            top: -40,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _sky.withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -50,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Palier actif',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('ACTIF',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.6)),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(planName,
                    style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Text(
                  'Commission plateforme : $commission% — prélevée uniquement sur vos ventes.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Progression vers le palier suivant ──────────────────────────────
  Widget _buildProgressionCard() {
    final p = _progression!;
    final next = p['palier_suivant'] as Map<String, dynamic>?;
    if (next == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: Colors.amber.shade600, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text("Vous avez atteint le palier le plus avancé 🎉",
                  style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }
    String fmtNum(double v) => v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toString();

    Widget row(String label, IconData icon, double current, double target) {
      final pct = target > 0 ? (current / target).clamp(0.0, 1.0) : 1.0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: _blue),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                Text('${fmtNum(current)} / ${fmtNum(target)}',
                    style: TextStyle(
                        color: pct >= 1 ? Colors.green.shade700 : _orange,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
                const SizedBox(width: 6),
                SizedBox(
                  width: 42,
                  child: Text('${(pct * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: pct >= 1 ? Colors.green.shade700 : Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: pct.toDouble(),
                minHeight: 10,
                backgroundColor: const Color(0xFFE8EEF3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  pct >= 1 ? Colors.green : _blue,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _orange.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Progression vers « ${next['name']} »',
              style: const TextStyle(fontWeight: FontWeight.w800, color: _navy, fontSize: 16)),
          const SizedBox(height: 14),
          row('Abonnés', Icons.people_alt_outlined, _toNum(p['abonnes']), _toNum(next['min_subscribers'])),
          row('Publications', Icons.article_outlined, _toNum(p['publications']), _toNum(next['min_publications'])),
          row('Ventes', Icons.payments_outlined, _toNum(p['ventes']), _toNum(next['min_sales'])),
        ],
      ),
    );
  }

  // ─── CARTE d'un palier avec TOUS ses avantages ────────────────────────
  // Chaque palier s'affiche comme une carte complète : en-tête (nom, icône,
  // badge « Palier actuel ») puis la liste détaillée de ses avantages réels
  // (fonctionnalités, commission, badge vérifié, mise en avant, export
  // des stats, etc.) — voir PlatformPlanSerializer côté backend.
  Widget _buildPlanTile(Map<String, dynamic> plan) {
    final isCurrent = _subscription != null && _subscription!['plan'] == plan['id'];
    final name = plan['name']?.toString() ?? '';

    final IconData icon = switch (name) {
      'Premium' => Icons.diamond_rounded,
      'Standard' => Icons.star_rounded,
      _ => Icons.eco_rounded,
    };

    // Avantages détaillés, toujours affichés (les valeurs du backend ont
    // des défauts sains, donc jamais de carte « vide »).
    // Les montants/taux arrivent en chaînes ('20.00', '15000.00') : on les
    // parse via _toNum pour ne JAMAIS planter sur un cast (voir plus haut).
    final commissionRate = _toNum(plan['commission_rate'], -1);
    final minWithdrawal = _toNum(plan['min_withdrawal_amount']);
    final maxWithdrawal = _toNum(plan['max_withdrawal_amount']);
    final maxReaderPlans = _toNum(plan['max_reader_plans']);
    final maxPrioritySlots = _toNum(plan['max_priority_slots']);
    final commissionLabel = commissionRate >= 0
        ? (commissionRate == commissionRate.roundToDouble()
            ? commissionRate.toStringAsFixed(0)
            : commissionRate.toString())
        : '—';
    String fmt(num v) => v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toString();

    final List<String> advantages = <String>[
      'Commission plateforme : $commissionLabel%',
      'Mise en avant simultanée : ${fmt(maxPrioritySlots)} publication(s)',
      'Offres d\'abonnement : ${fmt(maxReaderPlans)}${maxReaderPlans == 0 ? ' (illimité)' : ''}',
      if (plan['has_verified_badge'] == true) 'Badge « Vérifié » sur votre profil public',
      if (minWithdrawal > 0) 'Retrait minimum : ${fmt(minWithdrawal)} FCFA',
      if (maxWithdrawal > 0) 'Retrait maximum : ${fmt(maxWithdrawal)} FCFA',
      if (plan['has_stats_export'] == true) 'Export CSV de vos statistiques détaillées',
    ];

    final features = (plan['features_list'] as List?)?.cast<String>() ?? [];
    if (features.isNotEmpty) {
      advantages.addAll(features);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent ? _orange : Colors.grey.shade200,
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrent
                ? _orange.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (isCurrent)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: const BoxDecoration(
                  color: _orange,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
                child: const Text('Palier actuel',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: isCurrent ? _orange.withValues(alpha: 0.15) : _blue.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: isCurrent ? _orange : _blue, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: _navy)),
                          if ((plan['description']?.toString() ?? '').isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(plan['description'].toString(),
                                style: const TextStyle(color: Colors.black54, fontSize: 12, height: 1.4)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFE8EEF3)),
                const SizedBox(height: 12),
                ...advantages.map(
                  (adv) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 17,
                            color: isCurrent ? _orange : Colors.green.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(adv,
                              style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.35)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
