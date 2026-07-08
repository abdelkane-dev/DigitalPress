import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../config/api_constants.dart';

class PurchaseHistoryScreen extends ConsumerStatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  ConsumerState<PurchaseHistoryScreen> createState() =>
      _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState
    extends ConsumerState<PurchaseHistoryScreen> {
  bool _isLoading = false;
  List<dynamic> _transactions = [];
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(ApiConstants.mesTransactions);
      if (res.statusCode == 200 && res.data != null) {
        List<dynamic> items;
        if (res.data is List) {
          items = res.data as List;
        } else if (res.data is Map && res.data['results'] != null) {
          items = res.data['results'] as List;
        } else {
          items = [];
        }
        // Filtrer uniquement les achats et abonnements (pas les recharges)
        setState(() {
          _transactions = items
              .where((tx) =>
                  tx['type_transaction'] == 'purchase' ||
                  tx['type_transaction'] == 'subscription')
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredTransactions {
    if (_selectedFilter == 'all') return _transactions;
    return _transactions
        .where((tx) => tx['type_transaction'] == _selectedFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2647),
        title: const Text(
          'Historique d\'achats',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadTransactions,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTransactions.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredTransactions.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _buildTransactionCard(
                              _filteredTransactions[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      ('all', 'Tous', Icons.list_rounded),
      ('purchase', 'Achats', Icons.receipt_long_rounded),
      ('subscription', 'Abonnements', Icons.card_membership_rounded),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(f.$3, size: 16,
                      color: isSelected ? Colors.white : const Color(0xFF0A2647)),
                  const SizedBox(width: 4),
                  Text(f.$2),
                ],
              ),
              onSelected: (_) => setState(() => _selectedFilter = f.$1),
              selectedColor: const Color(0xFF0A2647),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF0A2647),
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: Colors.grey.shade100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    final isSubscription = tx['type_transaction'] == 'subscription';
    final amount =
        double.tryParse(tx['montant_brut']?.toString() ?? '0') ?? 0.0;
    final status = tx['status'] as String? ?? 'pending';
    final dateStr = tx['created_at'] != null
        ? _formatDate(DateTime.tryParse(tx['created_at'].toString()))
        : '';
    final title = tx['publication_title'] as String? ??
        (isSubscription ? 'Abonnement' : 'Achat');

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
                color: isSubscription
                    ? const Color(0xFF8B5CF6).withAlpha(25)
                    : const Color(0xFF2C74B3).withAlpha(25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isSubscription
                    ? Icons.card_membership_rounded
                    : Icons.receipt_long_rounded,
                color: isSubscription
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFF2C74B3),
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
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                      const SizedBox(width: 10),
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
                  if (tx['reference'] != null)
                    Text(
                      'Réf: ${(tx['reference'] as String).substring(0, 8)}...',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade400),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '-${amount.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Color(0xFF0A2647),
                  ),
                ),
                if (tx['devise'] != null)
                  Text(
                    tx['devise'] as String,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 64,
              color: Color(0xFF2C74B3),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Aucun achat pour l\'instant',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0A2647),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vos achats d\'articles et d\'abonnements\napparaîtront ici.',
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
    final months = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}
