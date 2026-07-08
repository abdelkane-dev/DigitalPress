import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
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
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWalletData();
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
        SnackBar(content: Text('Erreur lors du chargement: $e')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Portefeuille'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWalletData,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Solde Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0A2647), Color(0xFF2C74B3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Solde disponible',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_balance.toStringAsFixed(0)} FCFA',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => _showRechargeDialog(),
                          icon: const Icon(Icons.add_card_rounded),
                          label: const Text('Recharger mon compte'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0A2647),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Historique des opérations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _transactions.isEmpty
                        ? const Center(child: Text('Aucune opération enregistrée'))
                        : ListView.separated(
                            itemCount: _transactions.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final tx = _transactions[index];
                              final isRecharge = tx['type_transaction'] == 'recharge';
                              final amount = double.tryParse(tx['montant_brut']?.toString() ?? '0') ?? 0;
                              final dateStr = tx['created_at'] != null 
                                  ? DateTime.tryParse(tx['created_at'].toString())?.toLocal().toString().split('.')[0] ?? ''
                                  : '';

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isRecharge ? Colors.green.shade50 : Colors.red.shade50,
                                  child: Icon(
                                    isRecharge ? Icons.arrow_downward : Icons.arrow_upward,
                                    color: isRecharge ? Colors.green : Colors.red,
                                  ),
                                ),
                                title: Text(isRecharge ? 'Recharge de compte' : (tx['publication_title'] ?? 'Abonnement / Achat')),
                                subtitle: Text(dateStr),
                                trailing: Text(
                                  '${isRecharge ? '+' : '-'}${amount.toStringAsFixed(0)} FCFA',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isRecharge ? Colors.green : Colors.red,
                                    fontSize: 16,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showRechargeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recharger le compte'),
        content: Column(
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
