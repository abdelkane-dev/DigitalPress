import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/services/app_notification_service.dart';
import '../../core/utils/friendly_error.dart';
import '../../config/api_constants.dart';
import '../../widgets/payment_selection_sheet.dart';

class ClientWalletScreen extends ConsumerStatefulWidget {
  const ClientWalletScreen({super.key});

  @override
  ConsumerState<ClientWalletScreen> createState() => _ClientWalletScreenState();
}

class _ClientWalletScreenState extends ConsumerState<ClientWalletScreen> {
  bool _isLoading = false;
  List<dynamic> _transactions = [];
  double _balance = 0.0;
  /// 0 = toutes les opérations, 1 = remboursements uniquement (demande
  /// explicite : le portefeuille doit afficher clairement les remboursements).
  int _tabIndex = 0;
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWalletData();
    ref.listenManual(realtimeEventProvider, (previous, next) {
      if (next != null) _loadWalletData();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadWalletData() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      
      final profileRes = await api.get(ApiConstants.profile);
      if (profileRes.statusCode == 200) {
        final profileData = profileRes.data is Map ? profileRes.data : {};
        setState(() {
          _balance = double.tryParse(profileData['solde']?.toString() ?? '0') ?? 0.0;
        });
      }

      final txRes = await api.get(ApiConstants.mesTransactions);
      if (txRes.statusCode == 200) {
        final data = txRes.data;
        List<dynamic> list = [];
        if (data is Map && data.containsKey('results')) {
          list = data['results'] as List? ?? [];
        } else if (data is List) {
          list = data;
        }
        setState(() {
          _transactions = list;
        });
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

  Future<void> _initiateRecharge() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) return;
    
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un montant valide')),
      );
      return;
    }

    Navigator.pop(context); // fermer la boîte de dialogue
    _amountController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentSelectionSheet(
        journalId: 'recharge',
        price: amount,
        isRecharge: true,
        onPaymentSuccess: () {
          _loadWalletData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Votre portefeuille a été rechargé ! ✓'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  static const _navy = Color(0xFF0A2647);
  static const _blue = Color(0xFF2C74B3);
  static const _sky = Color(0xFF56B4E9);
  static const _bg = Color(0xFFF5F7FB);

  // ─── MÊME HABILLAGE QUE LA COMPTABILITÉ (admin/éditeur) ───────────────
  // Le portefeuille du lecteur utilise le même CSS que les écrans
  // comptables : dégradé navy, cartes arrondies, icônes colorées — adapté
  // au côté lecteur (ce qu'il doit recharger) : solde + bouton « Recharger ».
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Mon Portefeuille',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadWalletData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : RefreshIndicator(
              color: _blue,
              onRefresh: _loadWalletData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildBalanceCard(),
                  const SizedBox(height: 20),
                  _buildHistoryTabs(),
                  const SizedBox(height: 12),
                  const Text('Historique des opérations',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.3)),
                  const SizedBox(height: 12),
                  if (_displayedTransactions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Center(
                        child: Text(
                          _tabIndex == 1
                              ? 'Aucun remboursement pour le moment'
                              : 'Aucune opération enregistrée',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ..._displayedTransactions.map(_buildTransactionCard),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  /// Liste affichée selon l'onglet : toutes les opérations, ou uniquement
  /// celles au statut `refunded` (remboursements clairement identifiés).
  List<dynamic> get _displayedTransactions {
    if (_tabIndex == 1) {
      return _transactions
          .where((tx) => (tx['status']?.toString() ?? '') == 'refunded')
          .toList();
    }
    return _transactions;
  }

  /// Petits onglets Opérations / Remboursements (avec compteurs) — même
  /// habillage que le reste de la page.
  Widget _buildHistoryTabs() {
    final refundedCount = _transactions
        .where((tx) => (tx['status']?.toString() ?? '') == 'refunded')
        .length;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _buildTabChip('Opérations', 0, _transactions.length),
          const SizedBox(width: 4),
          _buildTabChip('Remboursements', 1, refundedCount),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label, int index, int count) {
    final selected = _tabIndex == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? _navy : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Carte solde (dégradé navy → bleu, identique comptabilité) ─────────
  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_navy, Color(0xFF144272)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _sky.withValues(alpha: 0.15),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SOLDE DISPONIBLE',
                  style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
              const SizedBox(height: 6),
              Text(
                '${_balance.toStringAsFixed(0)} FCFA',
                style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -0.8),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showRechargeDialog(),
                icon: const Icon(Icons.add_card_rounded),
                label: const Text('Recharger mon compte'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _navy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Ligne d'opération (même style que le journal des écritures) ───────
  // Une transaction remboursée (status == 'refunded') est affichée
  // distinctement : icône retour + libellé « Remboursement » + montant en
  // orange — le portefeuille montre clairement les remboursements (demande
  // explicite).
  Widget _buildTransactionCard(dynamic tx) {
    final isRefund = (tx['status']?.toString() ?? '') == 'refunded';
    final isRecharge = tx['type_transaction'] == 'recharge';
    final amount = double.tryParse(tx['montant_brut']?.toString() ?? '0') ?? 0;
    final dateStr = tx['created_at'] != null
        ? DateTime.tryParse(tx['created_at'].toString())?.toLocal().toString().split('.')[0] ?? ''
        : '';
    final color = isRefund
        ? const Color(0xFFEA580C)
        : (isRecharge ? const Color(0xFF10B981) : const Color(0xFFEF4444));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isRefund ? const Color(0xFFEA580C).withValues(alpha: 0.25) : Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isRefund
                  ? Icons.replay_rounded
                  : (isRecharge ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded),
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRefund
                      ? 'Remboursement'
                      : (isRecharge
                          ? 'Recharge de compte'
                          : (tx['publication_title'] ?? 'Abonnement / Achat')),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF1E293B)),
                ),
                if (dateStr.isNotEmpty)
                  Text(dateStr, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
              ],
            ),
          ),
          if (isRefund)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Text('Remboursé',
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          Text('${isRecharge || isRefund ? '+' : '-'}${amount.toStringAsFixed(0)} FCFA',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: color)),
        ],
      ),
    );
  }

  void _showRechargeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recharger le compte'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Entrez le montant en FCFA à ajouter à votre portefeuille :',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Montant (FCFA)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: _initiateRecharge,
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }
}
