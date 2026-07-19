import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../config/api_constants.dart';

class EditeurComptabiliteScreen extends ConsumerStatefulWidget {
  const EditeurComptabiliteScreen({super.key});

  @override
  ConsumerState<EditeurComptabiliteScreen> createState() => _EditeurComptabiliteScreenState();
}

class _EditeurComptabiliteScreenState extends ConsumerState<EditeurComptabiliteScreen> {
  bool _isLoading = false;
  Map<String, dynamic> _soldeData = {};
  List<dynamic> _journal = [];
  final _amountController = TextEditingController();
  final _accountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadComptaData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  Future<void> _loadComptaData() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);

      // Charger le solde et les statistiques
      final soldeRes = await api.get(ApiConstants.soldeEditeur);
      if (soldeRes.statusCode == 200) {
        setState(() {
          _soldeData = soldeRes.data as Map<String, dynamic>? ?? {};
        });
      }

      // Charger le journal des écritures de l'éditeur
      final journalRes = await api.get(ApiConstants.journalEntreprise);
      if (journalRes.statusCode == 200) {
        setState(() {
          _journal = journalRes.data['results'] as List? ?? journalRes.data as List? ?? [];
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des données: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestWithdrawal() async {
    final amountText = _amountController.text.trim();
    final accountText = _accountController.text.trim();
    if (amountText.isEmpty || accountText.isEmpty) return;

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un montant valide')),
      );
      return;
    }

    final currentSolde = double.tryParse(_soldeData['solde_disponible']?.toString() ?? '0') ?? 0;
    if (amount > currentSolde) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solde disponible insuffisant')),
      );
      return;
    }

    Navigator.pop(context);
    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post(
        ApiConstants.demandeRetrait,
        data: {
          'montant': amount,
          'numero_compte': accountText,
          'mode_paiement': 'mobile_money',
        },
      );

      if (res.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande de retrait enregistrée et en attente de virement !'),
            backgroundColor: Colors.green,
          ),
        );
        _amountController.clear();
        _accountController.clear();
        _loadComptaData();
      }
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Service de retrait indisponible. Contactez l\'administrateur.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la demande : ${e.message}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur inattendue : $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final soldeDisp = double.tryParse(_soldeData['solde_disponible']?.toString() ?? '0') ?? 0;
    final totalEarned = double.tryParse(_soldeData['total_earned']?.toString() ?? '0') ?? 0;
    final commDeduites = double.tryParse(_soldeData['total_commissions_deduites']?.toString() ?? '0') ?? 0;
    final retraitsFact = double.tryParse(_soldeData['total_retraits_effectues']?.toString() ?? '0') ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comptabilité Éditeur'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadComptaData,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dashboard cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Solde Disponible',
                          '${soldeDisp.toStringAsFixed(0)} FCFA',
                          Colors.orange.shade700,
                          Icons.account_balance_wallet_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Gains Cumulés',
                          '${totalEarned.toStringAsFixed(0)} FCFA',
                          Colors.green.shade700,
                          Icons.trending_up_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Commissions Déduites',
                          '${commDeduites.toStringAsFixed(0)} FCFA',
                          Colors.red.shade700,
                          Icons.percent_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Retraits Effectués',
                          '${retraitsFact.toStringAsFixed(0)} FCFA',
                          Colors.blue.shade700,
                          Icons.outbox_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Action buttons
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: soldeDisp > 0 ? () => _showWithdrawalDialog() : null,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Demander un Retrait'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  const Text(
                    'Journal des écritures',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _journal.isEmpty
                      ? const Center(child: Text('Aucune écriture comptable.'))
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _journal.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final ecriture = _journal[index];
                            final montant = double.tryParse(ecriture['montant']?.toString() ?? '0') ?? 0;
                            final type = ecriture['type_ecriture'];
                            final dateStr = ecriture['date_ecriture'] != null
                                ? DateTime.tryParse(ecriture['date_ecriture'].toString())?.toLocal().toString().split('.')[0] ?? ''
                                : '';

                            Color amountColor = Colors.black;
                            String prefix = '';
                            if (type == 'recette') {
                              amountColor = Colors.green;
                              prefix = '+';
                            } else if (type == 'retrait' || type == 'commission') {
                              amountColor = Colors.red;
                              prefix = '-';
                            }

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              title: Text(
                                ecriture['libelle'] ?? 'Écriture sans libellé',
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '$dateStr\nDébit: ${ecriture['compte_debit']} / Crédit: ${ecriture['compte_credit']}',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                              trailing: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '$prefix${montant.toStringAsFixed(0)} FCFA',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: amountColor,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          )
        ],
      ),
    );
  }

  void _showWithdrawalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Demander un retrait'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Entrez le montant et le numéro de téléphone pour le virement Mobile Money :',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Montant (FCFA)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _accountController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Numéro Mobile Money (ex: +225...)',
                border: OutlineInputBorder(),
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
            onPressed: _requestWithdrawal,
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }
}
