import 'package:flutter/material.dart';
import '../../model/admin_poster.dart';

class PosterDetailsScreen extends StatelessWidget {
  final AdminPoster poster;
  final VoidCallback onWarn;
  final VoidCallback onToggleBan;
  final Function(double) onUpdateCommission;

  const PosterDetailsScreen({
    super.key,
    required this.poster,
    required this.onWarn,
    required this.onToggleBan,
    required this.onUpdateCommission,
  });

  Color _statusColor() {
    if (poster.isBanned) return Colors.red;
    if (poster.warnings > 0) return Colors.orange;
    return Colors.green;
  }

  String _statusText() {
    if (poster.isBanned) return 'Banni';
    if (poster.warnings > 0) return 'Sous surveillance';
    return 'Actif';
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  void _showCommissionDialog(BuildContext context) {
    final controller = TextEditingController(text: poster.commissionRate.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Modifier la commission'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fixer le taux de commission pour ${poster.fullName} :',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Commission (%)',
                  suffixText: '%',
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
              onPressed: () {
                final val = double.tryParse(controller.text.trim());
                if (val != null && val >= 0 && val <= 100) {
                  Navigator.pop(context);
                  onUpdateCommission(val);
                }
              },
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Détails du poster'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
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
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.blue.shade100,
                    child: Icon(
                      Icons.person,
                      size: 36,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    poster.fullName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    poster.mediaName,
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor().withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusText(),
                      style: TextStyle(
                        color: _statusColor(),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _InfoCard(
              title: 'Informations',
              children: [
                _InfoRow(label: 'Email', value: poster.email),
                _InfoRow(label: 'Média', value: poster.mediaName),
                _InfoRow(label: 'Commission', value: '${poster.commissionRate.toStringAsFixed(1)} %'),
                _InfoRow(label: 'Avertissements', value: '${poster.warnings}'),
                _InfoRow(label: 'Statut', value: _statusText()),
              ],
            ),
            const SizedBox(height: 18),
            _InfoCard(
              title: 'Statistiques',
              children: [
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.45,
                  children: [
                    _MiniStatCard(
                      title: 'Articles',
                      value: '${poster.totalArticles}',
                      icon: Icons.article,
                    ),
                    _MiniStatCard(
                      title: 'Publiés',
                      value: '${poster.publishedArticles}',
                      icon: Icons.publish,
                    ),
                    _MiniStatCard(
                      title: 'Brouillons',
                      value: '${poster.draftArticles}',
                      icon: Icons.edit_document,
                    ),
                    _MiniStatCard(
                      title: 'Vues',
                      value: '${poster.totalViews}',
                      icon: Icons.visibility,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            _InfoCard(
              title: 'Historique des avertissements',
              children: [
                if (poster.warningHistory.isEmpty)
                  const Text('Aucun avertissement pour ce poster.')
                else
                  ...poster.warningHistory.reversed.map(
                    (warning) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            warning.reason,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Date : ${_formatDate(warning.date)}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _InfoCard(
              title: 'Actions administrateur',
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showCommissionDialog(context),
                      icon: const Icon(Icons.percent_rounded),
                      label: const Text('Modifier commission'),
                    ),
                    ElevatedButton.icon(
                      onPressed: poster.isBanned ? null : onWarn,
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: const Text('Envoyer un avertissement'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onToggleBan,
                      icon: Icon(
                        poster.isBanned ? Icons.lock_open : Icons.block,
                      ),
                      label: Text(poster.isBanned ? 'Débannir' : 'Bannir'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label :',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MiniStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue.shade700, size: 20),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
