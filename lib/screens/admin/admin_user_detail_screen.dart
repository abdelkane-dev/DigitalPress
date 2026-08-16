import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/services/app_notification_service.dart';

/// Page de détail d'un utilisateur pour l'administrateur (demande
/// explicite) : nom, email, rôle, date de création, dernière activité,
/// achats/paiements, statut actif/suspendu/banni, historique des actions de
/// modération et, pour un éditeur, son statut de vérification + les
/// informations de son agence. Depuis cette page, l'admin peut Suspendre,
/// Bannir ou Réactiver le compte (avec motif, journalisé côté serveur).
class AdminUserDetailScreen extends ConsumerStatefulWidget {
  final int userId;
  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  ConsumerState<AdminUserDetailScreen> createState() =>
      _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends ConsumerState<AdminUserDetailScreen> {
  static const _navy = Color(0xFF0A2647);
  static const _blue = Color(0xFF2C74B3);

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _load();
    ref.listenManual(realtimeEventProvider, (previous, next) {
      if (next != null) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('accounts/admin/users/${widget.userId}/detail/');
      if (mounted) {
        setState(() => _user = res.data as Map<String, dynamic>);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'admin':
        return 'Administrateur';
      case 'publisher':
        return 'Éditeur';
      default:
        return 'Lecteur';
    }
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'admin':
        return Colors.purple;
      case 'publisher':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return '—';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return value.toString();
    final local = dt.toLocal();
    const months = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc',
    ];
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year} à $hh:$mm';
  }

  String _statusLabel() {
    final u = _user!;
    if (u['is_active'] != true) return 'Suspendu / Banni';
    return 'Actif';
  }

  Color _statusColor() {
    final u = _user!;
    if (u['is_active'] != true) return Colors.red;
    return Colors.green;
  }

  Future<void> _moderate(String action) async {
    final u = _user!;
    final isSuspendOrBan = action == 'suspend' || action == 'ban';
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          action == 'suspend'
              ? 'Suspendre ce compte ?'
              : action == 'ban'
                  ? 'Bannir ce compte ?'
                  : 'Réactiver ce compte ?',
          style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black87),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSuspendOrBan
                  ? '${u['username']} ne pourra plus se connecter. Action journalisée.'
                  : '${u['username']} pourra de nouveau se connecter normalement.',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            if (isSuspendOrBan) ...[
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Motif (obligatoire)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isSuspendOrBan ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (isSuspendOrBan && reasonController.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: Text(
              action == 'suspend'
                  ? 'Suspendre'
                  : action == 'ban'
                      ? 'Bannir'
                      : 'Réactiver',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.post(
        'accounts/admin/users/${widget.userId}/action/',
        data: {
          'action': action,
          'reason': isSuspendOrBan ? reasonController.text.trim() : '',
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'suspend'
                  ? 'Compte suspendu.'
                  : action == 'ban'
                      ? 'Compte banni.'
                      : 'Compte réactivé.',
            ),
            backgroundColor: isSuspendOrBan ? Colors.red : Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text(
          'Détails du compte',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('Erreur : $_error', textAlign: TextAlign.center),
                      TextButton(onPressed: _load, child: const Text('Réessayer')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _blue,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildIdentityCard(),
                      const SizedBox(height: 14),
                      _buildStatusCard(),
                      const SizedBox(height: 14),
                      _buildInfoCard(),
                      const SizedBox(height: 14),
                      if (_user!['publisher'] != null) ...[
                        _buildPublisherCard(),
                        const SizedBox(height: 14),
                      ],
                      _buildTransactionsCard(),
                      const SizedBox(height: 14),
                      _buildHistoryCard(),
                      const SizedBox(height: 14),
                      _buildActionsCard(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: Color(0xFF0F172A),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // ─── Identité ─────────────────────────────────────────────────────────
  Widget _buildIdentityCard() {
    final u = _user!;
    final role = u['role']?.toString();
    return _buildCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: _roleColor(role).withValues(alpha: 0.15),
            child: Text(
              (u['username']?.toString() ?? '?')[0].toUpperCase(),
              style: TextStyle(
                color: _roleColor(role),
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u['name']?.toString().isNotEmpty == true
                      ? u['name'].toString()
                      : u['username']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text('@${u['username']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(u['email']?.toString() ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                if (u['phone']?.toString().isNotEmpty == true)
                  Text('📱 ${u['phone']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _chip(_roleLabel(role), _roleColor(role)),
                    _chip(
                      u['is_verified'] == true ? 'Email vérifié' : 'Email non vérifié',
                      u['is_verified'] == true ? Colors.green : Colors.grey,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  // ─── Statut actuel ────────────────────────────────────────────────────
  Widget _buildStatusCard() {
    final u = _user!;
    final isActive = u['is_active'] == true;
    return _buildCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isActive ? Colors.green : Colors.red).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isActive ? Icons.check_circle_rounded : Icons.block_rounded,
              color: isActive ? Colors.green : Colors.red,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Statut du compte',
                  style: TextStyle(fontSize: 12, color: Color(0xFF757575), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  _statusLabel(),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _statusColor(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Informations générales ───────────────────────────────────────────
  Widget _buildInfoCard() {
    final u = _user!;
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Informations'),
          const SizedBox(height: 10),
          _infoRow('Compte créé le', _formatDate(u['date_joined'])),
          _infoRow('Dernière activité', _formatDate(u['last_login'])),
          _infoRow('Achats réussis', '${u['purchases_count'] ?? 0}'),
          // ─── CORRECTIF : les Decimal Django arrivent en CHAÎNES
          // ('15000.00'), jamais en num — un cast `as num` plante la page
          // (même classe de bug que poster_my_subscription_screen.dart,
          // voir CLAUDE.md) : on passe toujours par un parse défensif.
          _infoRow(
            'Total dépensé',
            '${double.tryParse(u['total_spent']?.toString() ?? '') ?? 0} FCFA',
          ),
          _infoRow('Transactions', '${u['transactions_count'] ?? 0}'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Éditeur : agence + vérification ──────────────────────────────────
  Widget _buildPublisherCard() {
    final p = _user!['publisher'] as Map<String, dynamic>;
    final verificationLabels = {
      'pending': ('En attente', Colors.orange),
      'approved': ('Validée', Colors.green),
      'rejected': ('Rejetée', Colors.red),
      null: ('Non soumise', Colors.grey),
    };
    final (vLabel, vColor) =
        verificationLabels[p['verification_status']] ?? ('Inconnu', Colors.grey);

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Profil éditeur'),
          const SizedBox(height: 10),
          _infoRow("Nom de l'agence", p['company_name']?.toString() ?? '—'),
          _infoRow('Commission', '${p['commission_rate'] ?? 0}%'),
          _infoRow(
            'Statut éditeur',
            p['is_active'] == true ? 'Actif' : 'Suspendu',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Vérification : ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              _chip(vLabel, vColor as Color),
            ],
          ),
          if (p['verification_submitted_at'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Dossier soumis le ${_formatDate(p['verification_submitted_at'])}'
                '${p['verification_reviewed_at'] != null ? ' — traité le ${_formatDate(p['verification_reviewed_at'])}' : ''}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ),
          if ((p['rejection_reason']?.toString() ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Motif du rejet : ${p['rejection_reason']}',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Achats / paiements récents ───────────────────────────────────────
  Widget _buildTransactionsCard() {
    final txs = (_user!['recent_transactions'] as List? ?? []);
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Achats & paiements récents'),
          const SizedBox(height: 10),
          if (txs.isEmpty)
            Text(
              'Aucune transaction.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            )
          else
            ...txs.map((tx) {
              final type = tx['type_transaction']?.toString() ?? '';
              final montant = double.tryParse(tx['montant_brut']?.toString() ?? '0') ?? 0;
              final status = tx['status']?.toString() ?? '';
              final statusColor = status == 'success'
                  ? Colors.green
                  : status == 'failed' || status == 'cancelled'
                      ? Colors.red
                      : Colors.orange;
              final typeLabel = switch (type) {
                'purchase' => 'Achat',
                'subscription' => 'Abonnement',
                'recharge' => 'Recharge',
                'withdrawal' => 'Retrait',
                'featured' => 'Mise en avant',
                _ => type,
              };
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        typeLabel,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                    ),
                    Text(
                      '${montant.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    _chip(status, statusColor),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─── Historique des actions de modération ─────────────────────────────
  Widget _buildHistoryCard() {
    final history = (_user!['status_history'] as List? ?? []);
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Historique de modération'),
          const SizedBox(height: 10),
          if (history.isEmpty)
            Text(
              "Aucune suspension / bannissement enregistré.",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            )
          else
            ...history.map((h) {
              final action = h['action']?.toString() ?? '';
              final (label, color) = switch (action) {
                'suspend' => ('Suspendu', Colors.orange),
                'ban' => ('Banni', Colors.red),
                'reactivate' => ('Réactivé', Colors.green),
                _ => (action, Colors.grey),
              };
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (color as Color).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        action == 'reactivate' ? Icons.restore_rounded : Icons.gavel_rounded,
                        color: color,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$label — ${_formatDate(h['created_at'])}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                          ),
                          if ((h['reason']?.toString() ?? '').isNotEmpty)
                            Text(
                              h['reason'].toString(),
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          if (h['performed_by'] != null)
                            Text(
                              'Par ${h['performed_by']}',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────
  Widget _buildActionsCard() {
    final isActive = _user!['is_active'] == true;
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Actions'),
          const SizedBox(height: 12),
          if (isActive) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _moderate('suspend'),
                icon: const Icon(Icons.pause_circle_outline_rounded, size: 20),
                label: const Text('Suspendre le compte'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange.shade800,
                  side: BorderSide(color: Colors.orange.shade400),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _moderate('ban'),
                icon: const Icon(Icons.block_rounded, size: 20),
                label: const Text('Bannir le compte'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _moderate('reactivate'),
                icon: const Icon(Icons.restore_rounded, size: 20),
                label: const Text('Réactiver le compte'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
