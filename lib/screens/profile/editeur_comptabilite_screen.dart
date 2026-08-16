import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/services/app_notification_service.dart';
import '../../core/utils/friendly_error.dart';
import '../../config/api_constants.dart';
import '../../widgets/withdrawal_request_sheet.dart';

/// Comptabilité éditeur — version 2026 :
///  • cartes de solde/gains modernes,
///  • bouton « Retirer des fonds » avec choix SÉLECTIF du moyen de retrait
///    (Wave, Orange Money, Moov Money, carte bancaire) puis saisie du
///    montant que l'éditeur souhaite récupérer,
///  • suivi des demandes de retrait (statut) + journal des écritures.
class EditeurComptabiliteScreen extends ConsumerStatefulWidget {
  const EditeurComptabiliteScreen({super.key});

  @override
  ConsumerState<EditeurComptabiliteScreen> createState() =>
      _EditeurComptabiliteScreenState();
}

class _EditeurComptabiliteScreenState
    extends ConsumerState<EditeurComptabiliteScreen> {
  static const _navy = Color(0xFF0A2647);
  static const _blue = Color(0xFF2C74B3);
  static const _sky = Color(0xFF56B4E9);
  static const _bg = Color(0xFFF5F7FB);
  static const _orange = Color(0xFFEA580C);

  bool _isLoading = false;
  Map<String, dynamic> _soldeData = {};
  List<dynamic> _journal = [];
  List<dynamic> _remboursements = [];

  @override
  void initState() {
    super.initState();
    _loadComptaData();
    ref.listenManual(realtimeEventProvider, (previous, next) {
      if (next != null) _loadComptaData();
    });
  }

  Future<void> _loadComptaData() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);

      final soldeRes = await api.get(ApiConstants.soldeEditeur);
      if (soldeRes.statusCode == 200) {
        _soldeData = soldeRes.data as Map<String, dynamic>? ?? {};
      }

      final journalRes = await api.get(ApiConstants.journalEntreprise);
      if (journalRes.statusCode == 200) {
        _journal = journalRes.data['results'] as List? ??
            journalRes.data as List? ??
            [];
      }

      final rembRes = await api.get(ApiConstants.remboursementsEditeur);
      if (rembRes.statusCode == 200) {
        final data = rembRes.data;
        _remboursements =
            (data is Map ? (data['results'] as List? ?? []) : (data as List? ?? []));
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

  Future<void> _demanderRetrait() async {
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
            content: Text('Demande de retrait enregistrée. Elle sera traitée par l’équipe.'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
        );
      }
      await _loadComptaData();
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
    final soldeDisp =
        double.tryParse(_soldeData['solde_disponible']?.toString() ?? '0') ?? 0;
    final totalEarned =
        double.tryParse(_soldeData['total_earned']?.toString() ?? '0') ?? 0;
    final commDeduites =
        double.tryParse(_soldeData['total_commissions_deduites']?.toString() ?? '0') ?? 0;
    final retraitsFact =
        double.tryParse(_soldeData['total_retraits_effectues']?.toString() ?? '0') ?? 0;
    final featuredSpent =
        double.tryParse(_soldeData['total_featured_spent']?.toString() ?? '0') ?? 0;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Comptabilité Éditeur',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadComptaData,
          ),
        ],
      ),
      body: _isLoading && _soldeData.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : RefreshIndicator(
              onRefresh: _loadComptaData,
              color: _blue,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildBalanceCard(soldeDisp, totalEarned),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard('Commissions', commDeduites, const Color(0xFFEF4444), Icons.percent_rounded),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatCard('Retraits effectués', retraitsFact, _blue, Icons.outbox_rounded),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatCard('Mises en avant', featuredSpent, const Color(0xFFB45309), Icons.star_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildWithdrawalCta(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Remboursements'),
                  const SizedBox(height: 8),
                  if (_remboursements.isEmpty)
                    _buildEmptyCard('Aucun remboursement lié à votre compte.')
                  else
                    ..._remboursements.map((r) => _buildRemboursementCard(r)),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Journal des écritures'),
                  const SizedBox(height: 8),
                  if (_journal.isEmpty)
                    _buildEmptyCard('Aucune écriture comptable.')
                  else
                    ..._journal.map((e) => _buildEcritureCard(e)),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // ─── Carte solde (dégradé navy → bleu) ─────────────────────────────────
  Widget _buildBalanceCard(double solde, double earned) {
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
                '${solde.toStringAsFixed(0)} FCFA',
                style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -0.8),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.trending_up_rounded, color: Color(0xFF4ADE80), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Gains cumulés : ${earned.toStringAsFixed(0)} FCFA',
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(value.toStringAsFixed(0),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
          const SizedBox(height: 2),
          Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─── Bouton principal « Retirer des fonds » ────────────────────────────
  Widget _buildWithdrawalCta() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _demanderRetrait,
        icon: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
        label: const Text('Retirer des fonds',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _orange,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.3));
  }

  Widget _buildEmptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Text(text, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      ),
    );
  }

  // ─── Carte d'un remboursement (vue éditeur) ───────────────────────────
  // La vue change selon le type de compte : côté éditeur, chaque ligne
  // indique le SENS de l'opération pour SON compte :
  //   • « Vente remboursée »  — une de ses ventes a été annulée (revenu
  //     retiré, montant en rouge) ;
  //   • « Remboursement reçu » — l'éditeur (ou sa publication) était le
  //     payeur : l'argent lui a été recrédité (montant en vert).
  Widget _buildRemboursementCard(Map<String, dynamic> r) {
    final isSale = r['sens']?.toString() == 'vente';
    final montant = double.tryParse(r['montant_brut']?.toString() ?? '0') ?? 0;
    final title = r['publication_title']?.toString() ?? 'Remboursement';
    final dateStr = r['processed_at'] != null
        ? DateTime.tryParse(r['processed_at'].toString())?.toLocal().toString().split('.')[0] ?? ''
        : (r['created_at'] != null
            ? DateTime.tryParse(r['created_at'].toString())?.toLocal().toString().split('.')[0] ?? ''
            : '');
    final color = isSale ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFFEA580C).withValues(alpha: 0.1),
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
                  isSale ? 'Vente remboursée' : 'Remboursement reçu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: Color(0xFF1E293B)),
                ),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                if (dateStr.isNotEmpty)
                  Text(dateStr,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Text('${isSale ? '-' : '+'}${montant.toStringAsFixed(0)} FCFA',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: color)),
        ],
      ),
    );
  }

  // ─── Ligne du journal comptable ────────────────────────────────────────
  Widget _buildEcritureCard(Map<String, dynamic> ecriture) {
    final montant = double.tryParse(ecriture['montant']?.toString() ?? '0') ?? 0;
    final type = ecriture['type_ecriture']?.toString();
    final dateStr = ecriture['date_ecriture'] != null
        ? DateTime.tryParse(ecriture['date_ecriture'].toString())?.toLocal().toString().split('.')[0] ?? ''
        : '';

    final (color, prefix) = type == 'recette'
        ? (const Color(0xFF10B981), '+')
        : (const Color(0xFFEF4444), '-');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              type == 'recette' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ecriture['libelle'] ?? 'Écriture',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF1E293B))),
                Text(dateStr,
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Text('$prefix${montant.toStringAsFixed(0)} FCFA',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: color)),
        ],
      ),
    );
  }
}
