import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:digital_press/core/api/api_client.dart';
import 'package:digital_press/config/api_constants.dart';
import 'package:digital_press/model/publication.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Service Publication (Riverpod)
// Remplace ContenuService + ancienne ContenuProvider (ChangeNotifier)
// ─────────────────────────────────────────────────────────────────────────────

final publicationServiceProvider = Provider<PublicationService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PublicationService(apiClient);
});

class PublicationService {
  final ApiClient _api;
  PublicationService(this._api);

  Future<List<Publication>> getPublications({
    int page = 1,
    String? search,
    String? category,
    String? type,
    bool? isFree,
    int? publisherId,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      if (search != null && search.isNotEmpty) 'search': search,
      if (category != null && category.isNotEmpty) 'category': category,
      if (type != null && type.isNotEmpty) 'pub_type': type,
      if (isFree != null) 'is_free': isFree,
      if (publisherId != null) 'publisher_id': publisherId,
    };
    final res =
        await _api.get(ApiConstants.publications, queryParameters: params);
    final results = res.data['results'] as List? ?? res.data as List? ?? [];
    return results
        .map((j) => Publication.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Publication> getPublication(int id) async {
    final res = await _api.get('${ApiConstants.publications}$id/');
    return Publication.fromJson(res.data as Map<String, dynamic>);
  }

  /// Récupère l'URL réelle et complète du fichier d'une publication.
  ///
  /// Le backend vérifie ici l'accès (abonnement actif, achat, gratuité ou
  /// propriété) avant de renvoyer le lien : contrairement au champ `file_url`
  /// éventuellement présent dans la réponse de liste/détail (qui reste vide
  /// pour un utilisateur non autorisé), cet appel est la source de vérité
  /// pour savoir quel document afficher dans le lecteur PDF.
  Future<String> getProtectedFileUrl(int id) async {
    final res = await _api.get(ApiConstants.publicationFile(id.toString()));
    return (res.data as Map<String, dynamic>)['file_url']?.toString() ?? '';
  }

  Future<List<Publication>> getMyPublications() async {
    final res = await _api.get(ApiConstants.myPublications);
    final results = res.data['results'] as List? ?? res.data as List? ?? [];
    return results
        .map((j) => Publication.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Publication> createPublication(Map<String, dynamic> data) async {
    final res = await _api.post(ApiConstants.createPublication, data: data);
    return Publication.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Publication> updatePublication(
      int id, Map<String, dynamic> data) async {
    final res =
        await _api.patch('${ApiConstants.myPublications}$id/', data: data);
    return Publication.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deletePublication(int id) async {
    await _api.delete('${ApiConstants.myPublications}$id/');
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final res = await _api.get('${ApiConstants.publications}categories/');
    final results = res.data['results'] as List? ?? res.data as List? ?? [];
    return results.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createCategory(String name) async {
    final res = await _api.post(
      '${ApiConstants.publications}categories/',
      data: {'name': name},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<bool> toggleCategoryFavorite(int categoryId) async {
    final res = await _api.post(
      '${ApiConstants.publications}reader/categories/$categoryId/favorite/',
    );
    return res.data['favorited'] as bool? ?? false;
  }

  Future<List<Map<String, dynamic>>> getPublicPublishers() async {
    final res = await _api.get(ApiConstants.publicPublishers);
    final results = res.data as List? ?? [];
    return results.cast<Map<String, dynamic>>();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Publication List State (Riverpod StateNotifier)
// ─────────────────────────────────────────────────────────────────────────────

class PublicationListState {
  final List<Publication> items;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int currentPage;

  const PublicationListState({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.currentPage = 1,
  });

  PublicationListState copyWith({
    List<Publication>? items,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? currentPage,
  }) {
    return PublicationListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class PublicationListNotifier extends StateNotifier<PublicationListState> {
  final PublicationService _service;

  PublicationListNotifier(this._service) : super(const PublicationListState());

  Future<void> load({
    bool refresh = false,
    String? search,
    String? category,
    String? type,
    bool? isFree,
    int? publisherId,
  }) async {
    if (refresh) {
      state = const PublicationListState();
    }
    if (!state.hasMore || state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await _service.getPublications(
        page: state.currentPage,
        search: search,
        category: category,
        type: type,
        isFree: isFree,
        publisherId: publisherId,
      );
      if (items.isEmpty) {
        state = state.copyWith(isLoading: false, hasMore: false);
      } else {
        state = state.copyWith(
          items: [...state.items, ...items],
          isLoading: false,
          currentPage: state.currentPage + 1,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

final publicationListProvider =
    StateNotifierProvider<PublicationListNotifier, PublicationListState>((ref) {
  final service = ref.watch(publicationServiceProvider);
  return PublicationListNotifier(service);
});

final publicPublishersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(publicationServiceProvider);
  return service.getPublicPublishers();
});

final myPublicationsProvider = FutureProvider<List<Publication>>((ref) async {
  final service = ref.watch(publicationServiceProvider);
  return service.getMyPublications();
});

final publicationDetailProvider =
    FutureProvider.family<Publication, int>((ref, id) async {
  final service = ref.watch(publicationServiceProvider);
  return service.getPublication(id);
});

final categoriesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(publicationServiceProvider);
  return service.getCategories();
});

final publisherPublicationsListProvider = StateNotifierProvider<
    PublisherPublicationsListNotifier, AsyncValue<List<Publication>>>((ref) {
  final service = ref.watch(publicationServiceProvider);
  return PublisherPublicationsListNotifier(service);
});

class PublisherPublicationsListNotifier
    extends StateNotifier<AsyncValue<List<Publication>>> {
  final PublicationService _service;

  PublisherPublicationsListNotifier(this._service)
      : super(const AsyncValue.loading()) {
    loadMyPublications();
  }

  Future<void> loadMyPublications() async {
    state = const AsyncValue.loading();
    try {
      final list = await _service.getMyPublications();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> createPublication(Map<String, dynamic> data) async {
    try {
      final newPub = await _service.createPublication(data);
      state.whenData((list) {
        state = AsyncValue.data([newPub, ...list]);
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updatePublication(int id, Map<String, dynamic> data) async {
    try {
      final updated = await _service.updatePublication(id, data);
      state.whenData((list) {
        state =
            AsyncValue.data(list.map((p) => p.id == id ? updated : p).toList());
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> toggleStatus(int id, String currentStatus) async {
    try {
      final newStatus = currentStatus == 'published' ? 'draft' : 'published';
      final updated =
          await _service.updatePublication(id, {'status': newStatus});
      state.whenData((list) {
        state =
            AsyncValue.data(list.map((p) => p.id == id ? updated : p).toList());
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deletePublication(int id) async {
    try {
      await _service.deletePublication(id);
      state.whenData((list) {
        state = AsyncValue.data(list.where((p) => p.id != id).toList());
      });
    } catch (e) {
      rethrow;
    }
  }
}
