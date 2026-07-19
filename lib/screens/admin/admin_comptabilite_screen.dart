import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../config/api_constants.dart';

class AdminComptabiliteScreen extends ConsumerStatefulWidget {
  const AdminComptabiliteScreen({super.key});

  @override
  ConsumerState<AdminComptabiliteScreen> createState() =>
      _AdminComptabiliteScreenState();
}

class _AdminComptabiliteScreenState
    extends ConsumerState<AdminComptabiliteScreen> {
  bool _isLoading = false;
  Map<String, dynamic> _stats = {};
  List<dynamic> _journal = [];
  List<dynamic> _reconciliations = [];
  List<dynamic> _soldes = [];
  final _withdrawAmountController = TextEditingController();
  final _withdrawAccountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAdminCompta();
  }

  @override
  void dispose() {
    _withdrawAmountController.dispose();
    _withdrawAccountController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminCompta() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);

      // 1. Stats globales
      final statsRes = await api.get(ApiConstants.dashboardStats);
      if (statsRes.statusCode == 200) {
        _stats = statsRes.data as Map<String, dynamic>? ?? {};
      }

      // 2. Journal général des écritures
      final journalRes = await api.get(ApiConstants.journalAdmin);
      if (journalRes.statusCode == 200) {
        _journal = journalRes.data['results'] as List? ??
            journalRes.data as List? ??
            [];
      }

      // 3. Réconciliations mensuelles
      final reconRes = await api.get(ApiConstants.reconciliation);
      if (reconRes.statusCode == 200) {
        _reconciliations =
            reconRes.data['results'] as List? ?? reconRes.data as List? ?? [];
      }

      // 4. Soldes de chaque éditeur
      final soldesRes = await api.get(ApiConstants.adminSoldesEditeurs);
      if (soldesRes.statusCode == 200) {
        _soldes = soldesRes.data as List? ?? [];
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erreur lors de la récupération des données: $e')),
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
        data: {
          'mois': now.month,
          'annee': now.year,
        },
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Réconciliation générée et enregistrée avec succès ! ✓'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAdminCompta();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur réconciliation: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestWithdrawal() async {
    final amountText = _withdrawAmountController.text.trim();
    final accountText = _withdrawAccountController.text.trim();
    if (amountText.isEmpty || accountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez saisir un montant et un compte.')),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un montant valide.')),
      );
      return;
    }

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post(
        ApiConstants.demandeRetrait,
        data: {
          'montant': amount,
          'mode_paiement': 'mobile_money',
          'numero_compte': accountText,
        },
      );

      if (res.statusCode == 201) {
        if (!mounted) return;
        Navigator.of(context).pop();
        _withdrawAmountController.clear();
        _withdrawAccountController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande de retrait envoyée avec succès.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAdminCompta();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du retrait : $e')),
      );
    }
  }

  void _showWithdrawalDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Demander un retrait'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Saisissez le montant à retirer depuis votre compte.'),
              const SizedBox(height: 12),
              TextField(
                controller: _withdrawAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Montant (FCFA)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _withdrawAccountController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Compte / numéro Mobile Money',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: _requestWithdrawal,
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final caBrut =
        double.tryParse(_stats['chiffre_affaires_brut']?.toString() ?? '0') ??
            0;
    final comNet =
        double.tryParse(_stats['commissions_collectees']?.toString() ?? '0') ??
            0;
    final payouts =
        double.tryParse(_stats['retraits_valides']?.toString() ?? '0') ?? 0;
    final nbTx = _stats['nb_transactions_success'] ?? 0;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Comptabilité Générale'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Indicateurs'),
              Tab(text: 'Journal Général'),
              Tab(text: 'Réconciliations'),
              Tab(text: 'Soldes Éditeurs'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAdminCompta,
            )
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showWithdrawalDialog,
          icon: const Icon(Icons.payments_outlined),
          label: const Text(''),
          backgroundColor: const Color(0xFF0A2647),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // Tab 1: Stats globales
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildSummaryCard(
                          'Volume d\'affaires (Brut)',
                          '${caBrut.toStringAsFixed(0)} FCFA',
                          Colors.blue,
                          'Total des paiements effectués par les clients',
                        ),
                        const SizedBox(height: 16),
                        _buildSummaryCard(
                          'Commission Plateforme (Notre Part - 10%)',
                          '${comNet.toStringAsFixed(0)} FCFA',
                          Colors.amber.shade800,
                          'Bénéfice direct de la plateforme Digital Press',
                        ),
                        const SizedBox(height: 16),
                        _buildSummaryCard(
                          'Reversements Éditeurs (Part Médias - 90%)',
                          '${payouts.toStringAsFixed(0)} FCFA',
                          Colors.green,
                          'Retraits déjà effectués par les éditeurs',
                        ),
                        const SizedBox(height: 16),
                        _buildSummaryCard(
                          'Transactions Validées',
                          '$nbTx',
                          Colors.purple,
                          'Nombre total de ventes unitaires et d\'abonnements confirmés',
                        ),
                      ],
                    ),
                  ),

                  // Tab 2: Journal général
                  _journal.isEmpty
                      ? const Center(child: Text('Aucune écriture comptable.'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _journal.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final ecriture = _journal[index];
                            final amount = double.tryParse(
                                    ecriture['montant']?.toString() ?? '0') ??
                                0;
                            final dateStr = ecriture['date_ecriture'] != null
                                ? DateTime.tryParse(ecriture['date_ecriture']
                                            .toString())
                                        ?.toLocal()
                                        .toString()
                                        .split('.')[0] ??
                                    ''
                                : '';
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(ecriture['libelle'] ?? 'Écriture'),
                              subtitle: Text(
                                  '$dateStr\nCompte D: ${ecriture['compte_debit']} | C: ${ecriture['compte_credit']}'),
                              trailing: Text(
                                '${amount.toStringAsFixed(0)} FCFA',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        ),

                  // Tab 3: Réconciliations
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _triggerReconciliation,
                            icon: const Icon(Icons.compare_arrows_rounded),
                            label:
                                const Text('Lancer la réconciliation du mois'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0A2647),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: _reconciliations.isEmpty
                              ? const Center(
                                  child: Text(
                                      'Aucune réconciliation enregistrée.'))
                              : ListView.separated(
                                  itemCount: _reconciliations.length,
                                  separatorBuilder: (_, __) => const Divider(),
                                  itemBuilder: (context, index) {
                                    final rec = _reconciliations[index];
                                    return ListTile(
                                      title: Text(
                                          'Période: ${rec['periode_mois']}/${rec['periode_annee']}'),
                                      subtitle: Text(
                                          'Ecart: ${rec['ecart']} FCFA | Statut: ${rec['status'].toString().toUpperCase()}'),
                                      trailing: Chip(
                                        label: Text(
                                          rec['status'] == 'reconciled'
                                              ? 'OK'
                                              : 'ANOMALIE',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11),
                                        ),
                                        backgroundColor:
                                            rec['status'] == 'reconciled'
                                                ? Colors.green
                                                : Colors.red,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),

                  // Tab 4: Soldes éditeurs
                  _soldes.isEmpty
                      ? const Center(
                          child: Text('Aucun solde éditeur enregistré.'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _soldes.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final p = _soldes[index];
                            final solde = double.tryParse(
                                    p['solde']?.toString() ?? '0') ??
                                0;
                            final earned = double.tryParse(
                                    p['total_earned']?.toString() ?? '0') ??
                                0;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(p['company_name'] ?? p['username']),
                              subtitle: Text(
                                  'Taux de commission: ${p['commission_rate']}%'),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Solde: ${solde.toStringAsFixed(0)} FCFA',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Gains: ${earned.toStringAsFixed(0)} FCFA',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
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
      String title, String value, Color color, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 6)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 6),
          Text(subtitle,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ],
      ),
    );
  }
}
