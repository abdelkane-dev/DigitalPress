import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../config/api_constants.dart';
import 'payment_selection_sheet.dart';

/// Feuille de recharge de portefeuille — même design que withdrawal_request_sheet.
/// Étape 1 : choix du moyen (Wave, Orange, Moov, Carte, Virement)
/// Étape 2 : formulaire montant + infos
/// Renvoie true si lancée avec succès.
Future<bool> showRechargeWalletSheet(BuildContext context, {VoidCallback? onSuccess}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _RechargeWalletSheet(onSuccess: onSuccess),
  ).then((v) => v ?? false);
}

class _MethodInfo {
  final String value;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _MethodInfo({required this.value, required this.label, required this.subtitle, required this.icon, required this.color});
}

const List<_MethodInfo> _modes = [
  _MethodInfo(value: 'wave', label: 'Wave', subtitle: 'Rapide et sécurisé', icon: Icons.water_drop_rounded, color: Color(0xFF49B8E7)),
  _MethodInfo(value: 'orange_money', label: 'Orange Money', subtitle: 'Simple et sécurisé', icon: Icons.payments_rounded, color: Color(0xFFFF7900)),
  _MethodInfo(value: 'moov_money', label: 'Moov Money', subtitle: 'Paiement mobile Moov', icon: Icons.phone_android_rounded, color: Color(0xFF003399)),
  _MethodInfo(value: 'card', label: 'Carte Bancaire', subtitle: 'Visa, Mastercard — CinetPay', icon: Icons.credit_card_rounded, color: Color(0xFF635BFF)),
];

class _RechargeWalletSheet extends ConsumerStatefulWidget {
  final VoidCallback? onSuccess;
  const _RechargeWalletSheet({this.onSuccess});
  @override
  ConsumerState<_RechargeWalletSheet> createState() => _RechargeWalletSheetState();
}

class _RechargeWalletSheetState extends ConsumerState<_RechargeWalletSheet> {
  static const _navy = Color(0xFF0A2647);
  static const _accent = Color(0xFF10B981);

  final _amountController = TextEditingController();
  _MethodInfo? _selected;
  final bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _goBack() {
    setState(() => _selected = null);
  }

  void _proceedToPayment() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Montant invalide'), backgroundColor: Colors.red),
      );
      return;
    }
    Navigator.pop(context, true);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentSelectionSheet(
          journalId: 'recharge',
          price: amount,
          isRecharge: true,
          onPaymentSuccess: widget.onSuccess,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          if (_selected == null)
            Expanded(child: _buildMethodList())
          else
            Expanded(child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(0, 0, 0, MediaQuery.of(context).viewInsets.bottom + 20),
              child: Column(children: [_buildGradientHeader(), _buildSummary(), _buildFormSection()]),
            )),
        ],
      ),
    );
  }

  Widget _buildMethodList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recharger mon portefeuille', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _navy)),
                const SizedBox(height: 4),
                Text('Choisissez votre moyen de paiement', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ],
            )),
            IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: Colors.grey.shade400)),
          ]),
        ),
        const SizedBox(height: 16),
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _modes.length,
          itemBuilder: (ctx, i) {
            final m = _modes[i];
            return Padding(padding: const EdgeInsets.only(bottom: 10), child: InkWell(
              onTap: () => setState(() => _selected = m),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: m.color.withAlpha(25), shape: BoxShape.circle), child: Icon(m.icon, color: m.color)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(m.subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ])),
                  Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300),
                ]),
              ),
            ));
          },
        )),
      ],
    );
  }

  Widget _buildGradientHeader() {
    final m = _selected!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_navy, m.color.withAlpha(180)])),
      child: Column(children: [
        Row(children: [
          IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22), onPressed: _goBack),
          const Spacer(),
          IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: Colors.white.withAlpha(180), size: 22)),
        ]),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withAlpha(25), shape: BoxShape.circle), child: Icon(m.icon, color: Colors.white, size: 40)),
        const SizedBox(height: 12),
        Text(m.label, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(20)),
          child: const Text('Recharge', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  Widget _buildSummary() {
    final m = _selected!;
    final montant = _amountController.text.isNotEmpty ? _amountController.text : '—';
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: _navy.withAlpha(8), blurRadius: 20, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: m.color.withAlpha(25), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.receipt_long_rounded, color: m.color, size: 20)),
          const SizedBox(width: 12),
          const Text('Récapitulatif', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _navy)),
        ]),
        const SizedBox(height: 16),
        _summaryRow('Moyen de paiement', m.label),
        const Divider(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Montant à recharger', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _navy)),
          Text('$montant FCFA', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: m.color)),
        ]),
      ]),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
    ]);
  }

  Widget _buildFormSection() {
    final m = _selected!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: _navy.withAlpha(8), blurRadius: 20, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: m.color.withAlpha(25), borderRadius: BorderRadius.circular(8)), child: Icon(m.icon, color: m.color, size: 20)),
          const SizedBox(width: 12),
          const Text('Montant de la recharge', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _navy)),
        ]),
        const SizedBox(height: 20),
        const Text('Montant en FCFA', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Ex: 5000',
            prefixIcon: const Icon(Icons.attach_money_rounded, color: _accent),
            suffixText: 'FCFA',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _accent, width: 2)),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _accent.withAlpha(15), borderRadius: BorderRadius.circular(12), border: Border.all(color: _accent.withAlpha(50), width: 1)),
          child: Row(children: [Icon(Icons.info_outline_rounded, color: _accent, size: 20), const SizedBox(width: 12), Expanded(child: Text('Le montant sera débité de votre moyen de paiement et ajouté à votre portefeuille.', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)))]),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton(
            onPressed: _submitting ? null : _proceedToPayment,
            style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, disabledBackgroundColor: Colors.grey.shade300, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: const Text('Continuer vers le paiement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          ),
        ),
      ]),
    );
  }
}
