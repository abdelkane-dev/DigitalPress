import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../../model/models.dart';
import 'package:logger/logger.dart';

/// Fournisseur pour le service d'abonnements.
final abonnementServiceProvider = Provider<AbonnementService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AbonnementService(apiClient);
});

/// Service gérant les plans et abonnements clients.
class AbonnementService {
  final ApiClient _apiClient;
  final _logger = Logger();

  AbonnementService(this._apiClient);

  /// Récupère les plans d'abonnement actifs d'un éditeur.
  Future<List<AbonnementPlan>> getPlansForPublisher(int publisherId) async {
    try {
      final response = await _apiClient.get(
        'abonnements/plans/',
        queryParameters: {'publisher_id': publisherId},
      );
      final List<dynamic> data = response.data is Map
          ? (response.data['results'] as List? ?? [])
          : (response.data as List? ?? []);
      return data.map((json) => AbonnementPlan.fromJson(json)).toList();
    } catch (e) {
      _logger.e('Erreur lors de la récupération des plans d\'abonnement : $e');
      rethrow;
    }
  }

  /// Initialise un abonnement (statut 'pending').
  Future<Abonnement> createAbonnement(int planId) async {
    try {
      final response = await _apiClient.post(
        'abonnements/create/',
        data: {'plan': planId},
      );
      return Abonnement.fromJson(response.data);
    } catch (e) {
      _logger.e('Erreur lors de la création de l\'abonnement : $e');
      rethrow;
    }
  }

  /// Récupère la liste des abonnements de l'utilisateur connecté.
  Future<List<Abonnement>> getMyAbonnements() async {
    try {
      final response = await _apiClient.get('abonnements/my/');
      final List<dynamic> data = response.data is Map
          ? (response.data['results'] as List? ?? [])
          : (response.data as List? ?? []);
      return data.map((json) => Abonnement.fromJson(json)).toList();
    } catch (e) {
      _logger.e('Erreur lors de la récupération de mes abonnements : $e');
      rethrow;
    }
  }

  /// Récupère les plans créés par l'éditeur connecté.
  Future<List<AbonnementPlan>> getPublisherPlans() async {
    try {
      final response = await _apiClient.get('abonnements/plans/editeur/');
      final List<dynamic> data = response.data is Map
          ? (response.data['results'] as List? ?? [])
          : (response.data as List? ?? []);
      return data.map((json) => AbonnementPlan.fromJson(json)).toList();
    } catch (e) {
      _logger.e('Erreur lors du chargement des plans éditeur : $e');
      rethrow;
    }
  }

  /// Crée un nouveau plan d'abonnement.
  Future<AbonnementPlan> createPublisherPlan(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post(
        'abonnements/plans/editeur/',
        data: data,
      );
      return AbonnementPlan.fromJson(response.data);
    } catch (e) {
      _logger.e('Erreur création de plan : $e');
      rethrow;
    }
  }

  /// Modifie un plan d'abonnement existant.
  Future<AbonnementPlan> updatePublisherPlan(int planId, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.put(
        'abonnements/plans/editeur/$planId/',
        data: data,
      );
      return AbonnementPlan.fromJson(response.data);
    } catch (e) {
      _logger.e('Erreur modification de plan : $e');
      rethrow;
    }
  }

  /// Supprime un plan d'abonnement.
  Future<void> deletePublisherPlan(int planId) async {
    try {
      await _apiClient.delete('abonnements/plans/editeur/$planId/');
    } catch (e) {
      _logger.e('Erreur suppression de plan : $e');
      rethrow;
    }
  }
}

/// Fournisseur Riverpod pour charger dynamiquement les plans d'un éditeur.
final publisherPlansProvider = FutureProvider.family<List<AbonnementPlan>, int>((ref, publisherId) async {
  final service = ref.watch(abonnementServiceProvider);
  return service.getPlansForPublisher(publisherId);
});

final publisherPlansListProvider = StateNotifierProvider<PublisherPlansListNotifier, AsyncValue<List<AbonnementPlan>>>((ref) {
  final service = ref.watch(abonnementServiceProvider);
  return PublisherPlansListNotifier(service);
});

class PublisherPlansListNotifier extends StateNotifier<AsyncValue<List<AbonnementPlan>>> {
  final AbonnementService _service;

  PublisherPlansListNotifier(this._service) : super(const AsyncValue.loading()) {
    loadPlans();
  }

  Future<void> loadPlans() async {
    state = const AsyncValue.loading();
    try {
      final plans = await _service.getPublisherPlans();
      state = AsyncValue.data(plans);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> createPlan(Map<String, dynamic> data) async {
    try {
      final newPlan = await _service.createPublisherPlan(data);
      state.whenData((plans) {
        state = AsyncValue.data([...plans, newPlan]);
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updatePlan(int planId, Map<String, dynamic> data) async {
    try {
      final updated = await _service.updatePublisherPlan(planId, data);
      state.whenData((plans) {
        state = AsyncValue.data(plans.map((p) => p.id == planId ? updated : p).toList());
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deletePlan(int planId) async {
    try {
      await _service.deletePublisherPlan(planId);
      state.whenData((plans) {
        state = AsyncValue.data(plans.where((p) => p.id != planId).toList());
      });
    } catch (e) {
      rethrow;
    }
  }
}

