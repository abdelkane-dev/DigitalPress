import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/services/app_notification_service.dart';
import '../../core/utils/friendly_error.dart';
import '../../config/api_constants.dart';
import '../../widgets/withdrawal_request_sheet.dart';
import 'admin_withdrawals_screen.dart';

/// Comptabilité générale — version 2026 :
///  • onglets Indicateurs / Journal Général / Réconciliations / Soldes
///    Éditeurs, habillage moderne (cartes dégradées, statistiques),
///  • Retraits : l'admin peut gérer les demandes des éditeurs
///    (AdminWithdrawalsScreen) ET faire sa propre demande de retrait avec
///    le même système que l'éditeur (choix sélectif du moyen + montant).
class AdminComptabiliteScreen extends ConsumerStatefulWidget {
  const AdminComptabiliteScreen({super.key});

  @override
  ConsumerState<AdminComptabiliteScreen> createState() =>
      _AdminComptabiliteScreenState();
}

class _AdminComptabiliteScreenState
    extends ConsumerState<AdminComptabiliteScreen> {
  static const _navy = Color(0xFF0A2647);
  static const _blue = Color(0xFF2C74B3);
  static const _bg = Color(0xFFF5F7FB);

  bool _isLoading = false;
  Map<String, dynamic> _stats = {};
  List<dynamic> _journal = [];
  List<dynamic> _reconciliations = [];
  List<dynamic> _soldes = [];
  List<dynamic> _retraitsEnAttente = [];
  List<dynamic> _remboursements = [];

  @override
  void initState() {
    super.initState();
    _loadAdminCompta();
    ref.listenManual(realtimeEventProvider, (previous, next) {
      if (next != null) _loadAdminCompta();
    });
  }

  Future<void> _loadAdminCompta() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);

      final statsRes = await api.get(ApiConstants.dashboardStats);
      if (statsRes.statusCode == 200) {
        _stats = statsRes.data as Map<String, dynamic>? ?? {};
      }

      final journalRes = await api.get(ApiConstants.journalAdmin);
      if (journalRes.statusCode == 200) {
        _journal = journalRes.data['results'] as List? ??
            journalRes.data as List? ??
            [];
      }

      final reconRes = await api.get(ApiConstants.reconciliation);
      if (reconRes.statusCode == 200) {
        _reconciliations =
            reconRes.data['results'] as List? ?? reconRes.data as List? ?? [];
      }

      final soldesRes = await api.get(ApiConstants.adminSoldesEditeurs);
      if (soldesRes.statusCode == 200) {
        _soldes = soldesRes.data as List? ?? [];
      }

      final rembRes = await api.get(ApiConstants.remboursementsAdmin);
      if (rembRes.statusCode == 200) {
        _remboursements = rembRes.data as List? ?? [];
      }

      // Demandes de retrait en attente (badge « à traiter »).
      try {
        final retraitsRes = await api.get(
          ApiConstants.adminDemandesRetrait,
          queryParameters: {'status': 'pending'},
        );
        final data = retraitsRes.data;
        _retraitsEnAttente =
            (data is Map ? (data['results'] as List? ?? []) : (data as List? ?? []));
      } catch (_) {
        _retraitsEnAttente = [];
      }

      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerReconciliation() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final now = DateTime.now();
      final res = await api.post(
        ApiConstants.reconciliation,
        data: {'mois': now.month, 'annee': now.year},
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Réconciliation générée et enregistrée avec succès ! ✓'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
        );
        _loadAdminCompta();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Demande de retrait de l'ADMIN lui-même — même système que l'éditeur.
  Future<void> _demanderRetraitAdmin() async {
    final result = await showWithdrawalRequestSheet(context);
    if (result == null) return;
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post(
        ApiConstants.demandeRetrait,
        data: {
          'montant': double.tryParse(result['montant'] ?? '') ?? 0,
          'mode_paiement': result['mode'] ?? 'mobile_money',
          'numero_compte': result['numero'] ?? '',
          // Code OTP saisi dans la feuille (protection retraits frauduleux)
          'otp_code': result['otp_code'] ?? '',
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande de retrait enregistrée.'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
        );
      }
      await _loadAdminCompta();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyError(e)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
      );
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final caBrut =
        double.tryParse(_stats['chiffre_affaires_brut']?.toString() ?? '0') ?? 0;
    final comNet =
        double.tryParse(_stats['commissions_collectees']?.toString() ?? '0') ?? 0;
    final payouts =
        double.tryParse(_stats['retraits_valides']?.toString() ?? '0') ?? 0;
    final nbTx = _stats['nb_transactions_success'] ?? 0;
    final featuredRevenue =
        double.tryParse(_stats['featured_revenue']?.toString() ?? '0') ?? 0;
    final featuredCount = _stats['featured_count'] ?? 0;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _navy,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Comptabilité Générale',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          bottom: TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: const Color(0xFF56B4E9),
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            tabs: const [
              Tab(text: 'Indicateurs'),
              Tab(text: 'Journal Général'),
              Tab(text: 'Réconciliations'),
              Tab(text: 'Soldes Éditeurs'),
              Tab(text: 'Remboursements'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _loadAdminCompta,
            ),
          ],
        ),
        body: _isLoading && _stats.isEmpty
            ? const Center(child: CircularProgressIndicator(color: _blue))
            : TabBarView(
                children: [
                  // ── Tab 1 : Indicateurs + actions retraits ────────────
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildSummaryCard(
                          'Volume d’affaires (Brut)',
                          '${caBrut.toStringAsFixed(0)} FCFA',
                          const Color(0xFF2563EB),
                          Icons.payments_rounded,
                          'Total des paiements effectués par les clients',
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryCard(
                          'Commission Plateforme',
                          '${comNet.toStringAsFixed(0)} FCFA',
                          const Color(0xFFB45309),
                          Icons.percent_rounded,
                          'Bénéfice direct de la plateforme Digital Press',
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryCard(
                          'Reversements Éditeurs',
                          '${payouts.toStringAsFixed(0)} FCFA',
                          const Color(0xFF10B981),
                          Icons.outbox_rounded,
                          'Retraits effectués par les éditeurs',
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryCard(
                          'Transactions Validées',
                          '$nbTx',
                          const Color(0xFF8B5CF6),
                          Icons.receipt_long_rounded,
                          'Ventes unitaires et abonnements confirmés',
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryCard(
                          'Revenus des mises en avant (À la une)',
                          '${featuredRevenue.toStringAsFixed(0)} FCFA',
                          const Color(0xFFEA580C),
                          Icons.star_rounded,
                          '$featuredCount promotion(s) payante(s) — recette publicitaire 100% plateforme',
                        ),
                        const SizedBox(height: 20),
                        // ─── ACTIONS RETRAITS ───────────────────────────
                        // Même système côté admin : gérer les demandes des
                        // éditeurs + sa propre demande de retrait.
                        _buildRetraitActions(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

                  // ── Tab 2 : Journal général ────────────────────────────
                  _journal.isEmpty
                      ? const Center(child: Text('Aucune écriture comptable.'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _journal.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final ecriture = _journal[index];
                            final amount = double.tryParse(
                                    ecriture['montant']?.toString() ?? '0') ?? 0;
                            final dateStr = ecriture['date_ecriture'] != null
                                ? DateTime.tryParse(
                                            ecriture['date_ecriture'].toString())
                                        ?.toLocal()
                                        .toString()
                                        .split('.')[0] ??
                                    ''
                                : '';
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.grey.shade100),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      color: _blue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.receipt_long_rounded,
                                        color: _blue, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(ecriture['libelle'] ?? 'Écriture',
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                        Text(dateStr,
                                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
                                      ],
                                    ),
                                  ),
                                  Text('${amount.toStringAsFixed(0)} FCFA',
                                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                                ],
                              ),
                            );
                          },
                        ),

                  // ── Tab 3 : Réconciliations ────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _triggerReconciliation,
                            icon: const Icon(Icons.compare_arrows_rounded),
                            label: const Text('Lancer la réconciliation du mois'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _navy,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _reconciliations.isEmpty
                              ? const Center(
                                  child: Text('Aucune réconciliation enregistrée.'))
                              : ListView.separated(
                                  itemCount: _reconciliations.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final rec = _reconciliations[index];
                                    final ok = rec['status'] == 'reconciled';
                                    return Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            ok ? Icons.check_circle_rounded : Icons.error_rounded,
                                            color: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                            size: 22,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Période: ${rec['periode_mois']}/${rec['periode_annee']}',
                                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                                                Text('Ecart: ${rec['ecart']} FCFA',
                                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                              ],
                                            ),
                                          ),
                                          Chip(
                                            label: Text(ok ? 'OK' : 'ANOMALIE',
                                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                                            backgroundColor: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),

                  // ── Tab 4 : Soldes éditeurs ────────────────────────────
                  _soldes.isEmpty
                      ? const Center(child: Text('Aucun solde éditeur enregistré.'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _soldes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final p = _soldes[index];
                            final solde =
                                double.tryParse(p['solde']?.toString() ?? '0') ?? 0;
                            final earned =
                                double.tryParse(p['total_earned']?.toString() ?? '0') ?? 0;
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _blue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.storefront_rounded, color: _blue, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p['company_name'] ?? p['username'],
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                        Text('Taux de commission: ${p['commission_rate']}%',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('${solde.toStringAsFixed(0)} FCFA',
                                          style: const TextStyle(fontWeight: FontWeight.w900, color: _blue, fontSize: 14)),
                                      Text('Gains: ${earned.toStringAsFixed(0)} FCFA',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                  // ── Tab 5 : Remboursements (vue globale admin) ────────
                  _remboursements.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Aucun remboursement enregistré.'),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _remboursements.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final r = _remboursements[index];
                            final montant =
                                double.tryParse(r['montant_brut']?.toString() ?? '0') ?? 0;
                            final dateStr = r['processed_at'] != null
                                ? DateTime.tryParse(r['processed_at'].toString())?.toLocal().toString().split('.')[0] ?? ''
                                : (r['created_at'] != null
                                    ? DateTime.tryParse(r['created_at'].toString())?.toLocal().toString().split('.')[0] ?? ''
                                    : '');
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: const Color(0xFFEA580C).withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.replay_rounded,
                                        color: Color(0xFFEA580C), size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            r['publication_title']?.toString() ??
                                                'Remboursement',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700, fontSize: 13.5)),
                                        Text(
                                          '${r['payer_username'] ?? '—'} → ${r['beneficiaire_username'] ?? '—'}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 11.5, color: Colors.grey.shade500),
                                        ),
                                        if (dateStr.isNotEmpty)
                                          Text(dateStr,
                                              style: TextStyle(
                                                  fontSize: 11, color: Colors.grey.shade400)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('${montant.toStringAsFixed(0)} FCFA',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFFEA580C),
                                              fontSize: 14)),
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                              color: const Color(0xFFEA580C).withValues(alpha: 0.35)),
                                        ),
                                        child: const Text('Remboursé',
                                            style: TextStyle(
                                                color: Color(0xFFEA580C),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ],
              ),
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, Color color, IconData icon, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border(left: BorderSide(color: color, width: 5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetraitActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('RETRAITS',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.1)),
        const SizedBox(height: 10),
        // Gestion des demandes des éditeurs (badge si en attente).
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              await context.push('/admin/withdrawals');
              _loadAdminCompta();
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.assignment_return_rounded, color: Color(0xFF3B82F6), size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Demandes de retrait des éditeurs',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        Text('Approuver, rejeter ou compléter les retraits',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  if (_retraitsEnAttente.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${_retraitsEnAttente.length}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                    )
                  else
                    const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Demande de retrait de l'admin lui-même (même système qu'éditeur).
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _demanderRetraitAdmin,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF10B981), size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mon retrait',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        Text('Retirer des fonds (même système que les éditeurs)',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
