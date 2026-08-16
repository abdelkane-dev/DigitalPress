import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/warnings_service.dart';

class PosterWarningsScreen extends ConsumerWidget {
  const PosterWarningsScreen({super.key});

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warningsAsync = ref.watch(myWarningsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Avertissements reçus'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myWarningsProvider),
        child: warningsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 80),
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    Text('Impossible de charger vos avertissements.\n$err',
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ],
          ),
          data: (moderation) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: moderation.isBanned
                      ? Colors.red.shade50
                      : moderation.warningCount > 0
                          ? Colors.orange.shade50
                          : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: moderation.isBanned
                        ? Colors.red.shade200
                        : moderation.warningCount > 0
                            ? Colors.orange.shade200
                            : Colors.green.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      moderation.isBanned
                          ? 'Compte banni'
                          : moderation.warningCount > 0
                              ? 'Compte sous surveillance'
                              : 'Aucun avertissement',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Nombre total d’avertissements : ${moderation.warningCount}'),
                    const SizedBox(height: 4),
                    Text(
                      moderation.isBanned
                          ? 'Votre compte est suspendu jusqu’à nouvel ordre.'
                          : 'À 3 avertissements, le compte peut être banni temporairement.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Historique',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (moderation.warnings.isEmpty)
                const Text('Aucun avertissement reçu.')
              else
                ...moderation.warnings.map(
                  (warning) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
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
                      children: [
                        Text(
                          warning.reason,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Date : ${_formatDate(warning.date)}'),
                        Text('Émis par : ${warning.issuedBy}'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
