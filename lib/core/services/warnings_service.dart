import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../model/poster_received_warning.dart';
import '../api/api_client.dart';

/// État réel (et propre à chaque compte éditeur connecté) des avertissements
/// reçus de l'administration, ainsi que du statut de bannissement.
///
/// Remplace `poster_moderation_demo_store.dart`, qui renvoyait la même liste
/// figée pour tous les comptes éditeurs.
class WarningsState {
  final List<PosterReceivedWarning> warnings;
  final bool isBanned;

  const WarningsState({required this.warnings, required this.isBanned});

  int get warningCount => warnings.length;
  bool get isUnderWatch => warningCount > 0 && !isBanned;
}

final myWarningsProvider = FutureProvider.autoDispose<WarningsState>((ref) async {
  final apiClient = ref.watch(apiClientProvider);

  final warningsResponse = await apiClient.get('accounts/me/warnings/');
  final rawWarnings = warningsResponse.data is Map
      ? (warningsResponse.data['results'] as List? ?? [])
      : (warningsResponse.data as List? ?? []);

  final warnings = rawWarnings.map((json) {
    return PosterReceivedWarning(
      id: json['id'].toString(),
      reason: json['reason']?.toString() ?? '',
      date: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      issuedBy: json['issued_by_username']?.toString().isNotEmpty == true
          ? json['issued_by_username'].toString()
          : 'Administration',
    );
  }).toList();

  bool isBanned = false;
  try {
    final profileResponse = await apiClient.get('accounts/me/publisher-profile/');
    final data = profileResponse.data as Map<String, dynamic>;
    isBanned = data['is_active'] == false;
  } catch (_) {
    // Si le profil éditeur n'est pas disponible, on suppose un compte actif.
  }

  return WarningsState(warnings: warnings, isBanned: isBanned);
});
