import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

/// Statistiques globales de la plateforme — alimentées par le VRAI backend
/// (GET /api/comptabilite/admin/dashboard/stats/, voir
/// apps/comptabilite.utils.get_dashboard_stats) : utilisateurs, éditeurs,
/// revenus, commissions, mises en avant, abonnements actifs, etc.
class AdminStatisticsScreen extends ConsumerStatefulWidget {
  const AdminStatisticsScreen({super.key});

  @override
  ConsumerState<AdminStatisticsScreen> createState() =>
      _AdminStatisticsScreenState();
}

class _AdminStatisticsScreenState extends ConsumerState<AdminStatisticsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('comptabilite/admin/dashboard/stats/');
      if (mounted) {
        setState(() {
          _stats = (res.data as Map<String, dynamic>?) ?? {};
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  String _s(dynamic v, {String fallback = '0'}) {
    final s = v?.toString() ?? '';
    return s.isEmpty ? fallback : s;
  }

  String _fmt(dynamic v) {
    try {
      final d = double.parse(_s(v));
      return d.toStringAsFixed(0);
    } catch (_) {
      return _s(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques globales'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded,
                            size: 48, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        const Text('Impossible de charger les statistiques',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('$_error',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      GridView.count(
                        shrinkWrap: true,
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _StatCard(
                            title: 'Utilisateurs',
                            value: _fmt(_stats['total_users']),
                            icon: Icons.people_alt_rounded,
                            color: const Color(0xFF2C74B3),
                          ),
                          _StatCard(
                            title: 'Éditeurs',
                            value: _fmt(_stats['total_publishers']),
                            icon: Icons.edit_rounded,
                            color: const Color(0xFF7C3AED),
                          ),
                          _StatCard(
                            title: 'Lecteurs',
                            value: _fmt(_stats['total_readers']),
                            icon: Icons.menu_book_rounded,
                            color: const Color(0xFF0EA5E9),
                          ),
                          _StatCard(
                            title: 'Transactions réussies',
                            value: _fmt(_stats['nb_transactions_success']),
                            icon: Icons.receipt_long_rounded,
                            color: const Color(0xFFF59E0B),
                          ),
                          _StatCard(
                            title: 'Revenus totaux',
                            value: '${_fmt(_stats['revenue_total'])} FCFA',
                            icon: Icons.payments_rounded,
                            color: const Color(0xFF10B981),
                          ),
                          _StatCard(
                            title: 'Revenus du mois',
                            value: '${_fmt(_stats['revenue_month'])} FCFA',
                            icon: Icons.trending_up_rounded,
                            color: const Color(0xFF059669),
                          ),
                          _StatCard(
                            title: 'Commissions totales',
                            value: '${_fmt(_stats['commission_total'])} FCFA',
                            icon: Icons.percent_rounded,
                            color: const Color(0xFFDC2626),
                          ),
                          _StatCard(
                            title: 'Mises en avant',
                            value:
                                '${_fmt(_stats['featured_count'])} — ${_fmt(_stats['featured_revenue'])} FCFA',
                            icon: Icons.star_rounded,
                            color: const Color(0xFFEA580C),
                          ),
                          _StatCard(
                            title: 'Abonnements actifs',
                            value: _fmt(_stats['active_subscriptions']),
                            icon: Icons.subscriptions_rounded,
                            color: const Color(0xFF8B5CF6),
                          ),
                          _StatCard(
                            title: 'Soldes éditeurs',
                            value: '${_fmt(_stats['soldes_editeurs'])} FCFA',
                            icon: Icons.account_balance_wallet_rounded,
                            color: const Color(0xFF2563EB),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 10,
                              color: Colors.black12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Résumé détaillé',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _summaryRow('Utilisateurs totaux',
                                _fmt(_stats['total_users'])),
                            _summaryRow('Éditeurs',
                                _fmt(_stats['total_publishers'])),
                            _summaryRow('Lecteurs',
                                _fmt(_stats['total_readers'])),
                            _summaryRow('Chiffre d\'affaires brut',
                                '${_fmt(_stats['chiffre_affaires_brut'])} FCFA'),
                            _summaryRow('Revenu du mois',
                                '${_fmt(_stats['revenue_month'])} FCFA'),
                            _summaryRow('Croissance vs mois dernier',
                                '${_fmt(_stats['revenue_growth_pct'])}%'),
                            _summaryRow('Commissions collectées',
                                '${_fmt(_stats['commissions_collectees'])} FCFA'),
                            _summaryRow('Revenus mises en avant (À la une)',
                                '${_fmt(_stats['featured_revenue'])} FCFA '
                                '(${_fmt(_stats['featured_count'])} promotions)'),
                            _summaryRow('Abonnements actifs',
                                _fmt(_stats['active_subscriptions'])),
                            _summaryRow('Transactions réussies',
                                _fmt(_stats['nb_transactions_success'])),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.black87)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            color: Colors.black12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
