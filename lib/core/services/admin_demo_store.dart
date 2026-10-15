import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../../model/admin_poster.dart';
import '../../model/poster_warning.dart';
import 'package:logger/logger.dart';
import 'app_notification_service.dart';

final adminDemoStoreProvider =
    StateNotifierProvider<AdminStore, List<AdminPoster>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AdminStore(apiClient, ref);
});

class AdminStore extends StateNotifier<List<AdminPoster>> {
  final ApiClient _apiClient;
  final _logger = Logger();

  AdminStore(this._apiClient, Ref ref) : super([]) {
    loadPublishers();
    // Vue d'ensemble admin en temps réel : nouvelle transaction, nouveau
    // retrait à traiter, nouvelle vérification éditeur soumise... tout
    // admin connecté voit la liste/les stats se mettre à jour tout seul.
    ref.listen(realtimeEventProvider, (previous, next) {
      if (next != null && next.event == 'admin_stats_changed') {
        loadPublishers();
      }
    });
  }

  Future<void> loadPublishers() async {
    try {
      final response = await _apiClient.get('accounts/publishers/');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is Map
            ? (response.data['results'] as List? ?? [])
            : (response.data as List? ?? []);
        state = data.map((json) {
          return AdminPoster(
            id: json['id'].toString(),
            fullName: json['company_name']?.toString() ?? json['username']?.toString() ?? '',
            mediaName: json['company_name']?.toString() ?? 'Presse',
            email: json['email']?.toString() ?? '',
            warnings: 0, // Mock
            isBanned: !(json['is_active'] as bool? ?? true),
            commissionRate: double.tryParse(json['commission_rate']?.toString() ?? '10.0') ?? 10.0,
            warningHistory: const [],
          );
        }).toList();
      }
    } catch (e) {
      _logger.e('Erreur chargement editeurs admin : $e');
    }
  }

  Future<void> addPoster({
    required String fullName,
    required String mediaName,
    required String email,
    required String password,
  }) async {
    try {
      // Utilise l'endpoint admin dédié et protégé (IsAdmin) : l'ancien appel
      // à 'accounts/register/' (public) ne fonctionne plus pour créer un
      // éditeur depuis que ce endpoint force role='reader' pour des raisons
      // de sécurité (voir accounts/serializers.py — RegisterSerializer).
      final response = await _apiClient.post(
        'accounts/admin/create-publisher/',
        data: {
          'username': email,
          'email': email,
          'password': password,
          'name': fullName,
          'company_name': mediaName,
        },
      );
      if (response.statusCode == 201) {
        await loadPublishers();
      }
    } catch (e) {
      _logger.e('Erreur creation editeur : $e');
      rethrow;
    }
  }

  Future<void> addWarning({
    required String posterId,
    required String reason,
  }) async {
    // Persiste réellement l'avertissement en base (visible uniquement par
    // l'éditeur concerné) et déclenche une notification côté backend,
    // au lieu de ne modifier que l'état local Flutter comme auparavant.
    try {
      final response = await _apiClient.post(
        'accounts/warnings/issue/',
        data: {
          'publisher': int.tryParse(posterId) ?? posterId,
          'reason': reason,
          'severity': 'warning',
        },
      );

      state = state.map((poster) {
        if (poster.id != posterId) return poster;
        final newWarning = PosterWarning(
          id: response.data['id'].toString(),
          reason: reason,
          date: DateTime.tryParse(response.data['created_at']?.toString() ?? '') ??
              DateTime.now(),
        );
        return poster.copyWith(
          warnings: poster.warnings + 1,
          warningHistory: [...poster.warningHistory, newWarning],
        );
      }).toList();
    } catch (e) {
      _logger.e('Erreur ajout avertissement : $e');
      rethrow;
    }
  }

  Future<void> toggleBan(String posterId) async {
    try {
      final poster = state.firstWhere((p) => p.id == posterId);
      final newActiveStatus = poster.isBanned; // Si banni -> activer, si actif -> bannir

      final response = await _apiClient.put(
        'accounts/users/$posterId/',
        data: {
          'publisher_profile': {
            'is_active': newActiveStatus,
          }
        },
      );

      if (response.statusCode == 200) {
        state = state.map((p) {
          if (p.id != posterId) return p;
          return p.copyWith(isBanned: !newActiveStatus);
        }).toList();
      }
    } catch (e) {
      _logger.e('Erreur modification statut editeur : $e');
      rethrow;
    }
  }

  Future<void> updateCommissionRate(String posterId, double rate) async {
    try {
      final response = await _apiClient.put(
        'accounts/users/$posterId/',
        data: {
          'publisher_profile': {
            'commission_rate': rate,
          }
        },
      );

      if (response.statusCode == 200) {
        state = state.map((p) {
          if (p.id != posterId) return p;
          return p.copyWith(commissionRate: rate);
        }).toList();
      }
    } catch (e) {
      _logger.e('Erreur modification commission editeur : $e');
      rethrow;
    }
  }
}