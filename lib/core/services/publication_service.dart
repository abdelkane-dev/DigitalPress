import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:digital_press/core/api/api_client.dart';
import 'package:digital_press/config/api_constants.dart';
import 'package:digital_press/model/publication.dart';
import 'package:digital_press/model/conversation_message.dart';
import 'package:digital_press/core/storage/storage_service.dart';
import 'app_notification_service.dart';

// ─── TTL DU CACHE ──────────────────────────────────────────────────────────
// Durées adaptées au réseau malien (faible débit, coûts data élevés) :
//   - Liste publications : 5 min (données changeantes)
//   - Détail publication : 10 min (rarement modifié après publication)
//   - Catégories : 1 heure (quasi-statiques)
//   - Featured/Tendances : 15 min (mis à jour occasionnellement)
//   - Profil éditeur : 10 min
//   - Mes publications : 3 min (l'éditeur crée/modifie souvent)
const int _ttlList = 300;        // 5 min
const int _ttlDetail = 600;     // 10 min
const int _ttlCategories = 3600; // 1 hour
const int _ttlFeatured = 900;   // 15 min
const int _ttlProfile = 600;    // 10 min
const int _ttlMyPubs = 180;     // 3 min
/// Converts dynamic JSON map to Map\<String, dynamic\> safely.
/// On web, JSON decoding returns LinkedHashMap\<dynamic, dynamic\>,
/// which causes 'as Map\<String, dynamic\>' to fail at runtime.
Map<String, dynamic> _safeMap(dynamic j) {
  if (j is Map<String, dynamic>) return j;
  if (j is Map) return Map<String, dynamic>.from(j);
  return {};
}

List<Map<String, dynamic>> _safeMapList(dynamic list) {
  if (list == null || list is! List) return [];
  return list.map((item) => _safeMap(item)).toList();
}


final publicationServiceProvider = Provider<PublicationService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storageService = ref.watch(storageServiceProvider);
  return PublicationService(apiClient, storageService);
});

class PublicationService {
  final ApiClient _api;
  final StorageService _storage;
  PublicationService(this._api, this._storage);

  /// Récupère les publications avec cache TTL.
  /// 1. Affiche le cache immédiatement (instant UI)
  /// 2. Si le cache est stale (> grace period), refresh en arrière-plan
  /// 3. Si pas de cache, affiche un loading
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
      if (type != null && type.isNotEmpty) 'type': type,
      if (isFree != null) 'is_free': isFree,
      if (publisherId != null) 'publisher_id': publisherId,
    };
    final cacheKey = 'pubs_list_${page}_${search ?? ""}_${category ?? ""}_${type ?? ""}_${isFree ?? ""}_${publisherId ?? ""}';

    // 1. Servir le cache immédiatement
    final cached = _storage.getFromCache(cacheKey);
    if (cached != null) {
      final List results = cached is List ? cached : [];
      final pubs = results
          .map((j) => Publication.fromJson(_safeMap(j)))
          .toList();

      // 2. Si stale, refresh en arrière-plan (silencieux)
      if (_storage.isCacheStale(cacheKey, gracePeriod: 120)) {
        _refreshPublicationsInBackground(cacheKey, params);
      }

      return pubs;
    }

    // 3. Pas de cache → fetch depuis le réseau
    try {
      final res = await _api.get(ApiConstants.publications, queryParameters: params);
      final results = res.data['results'] as List? ?? res.data as List? ?? [];
      await _storage.setWithTTL(cacheKey, results, ttl: _ttlList);
      return results
          .map((j) => Publication.fromJson(_safeMap(j)))
          .toList();
    } catch (e) {
      // En cas d'erreur réseau, essayer le cache expiré (offline mode)
      final staleCache = _storage.get('cache_$cacheKey');
      if (staleCache != null && staleCache is Map && staleCache['data'] is List) {
        final List results = staleCache['data'];
        return results
            .map((j) => Publication.fromJson(_safeMap(j)))
            .toList();
      }
      rethrow;
    }
  }

  /// Refresh silencieux en arrière-plan — ne notifie pas l'UI tant que
  /// les données n'ont pas changé.
  void _refreshPublicationsInBackground(String cacheKey, Map<String, dynamic> params) {
    // Ne pas lancer de refresh si un refresh est déjà en cours
    if (_refreshing.contains(cacheKey)) return;
    _refreshing.add(cacheKey);

    _api.get(ApiConstants.publications, queryParameters: params).then((res) async {
      final results = res.data['results'] as List? ?? res.data as List? ?? [];
      await _storage.setWithTTL(cacheKey, results, ttl: _ttlList);
    }).catchError((_) {
      // Erreur silencieuse — le cache stale reste utilisable
    }).whenComplete(() {
      _refreshing.remove(cacheKey);
    });
  }

  final Set<String> _refreshing = {};

  Future<Publication> getPublication(int id) async {
    final cacheKey = 'pub_detail_$id';

    final cached = _storage.getFromCache(cacheKey);
    if (cached != null) {
      if (_storage.isCacheStale(cacheKey, gracePeriod: 120)) {
        _api.get('${ApiConstants.publications}$id/').then((res) async {
          await _storage.setWithTTL(cacheKey, res.data, ttl: _ttlDetail);
        }).catchError((_) {});
      }
      return Publication.fromJson(_safeMap(cached));
    }

    try {
      final res = await _api.get('${ApiConstants.publications}$id/');
      await _storage.setWithTTL(cacheKey, res.data, ttl: _ttlDetail);
      return Publication.fromJson(_safeMap(res.data));
    } catch (e) {
      // Fallback sur cache expiré
      final stale = _storage.get('cache_$cacheKey');
      if (stale != null && stale is Map) {
        return Publication.fromJson(_safeMap(stale['data']));
      }
      rethrow;
    }
  }

  Future<String> getProtectedFileUrl(int id) async {
    final res = await _api.get(ApiConstants.publicationFile(id.toString()));
    return _safeMap(res.data)['file_url']?.toString() ?? '';
  }

  Future<Map<String, List<Publication>>> getFeatured() async {
    const cacheKey = 'featured_publications';

    final cached = _storage.getFromCache(cacheKey);
    if (cached != null) {
      final data = _safeMap(cached);
      if (_storage.isCacheStale(cacheKey, gracePeriod: 180)) {
        _refreshFeaturedInBackground();
      }
      return {
        'featured': (data['featured'] as List? ?? [])
            .map((j) => Publication.fromJson(_safeMap(j)))
            .toList(),
        'trending': (data['trending'] as List? ?? [])
            .map((j) => Publication.fromJson(_safeMap(j)))
            .toList(),
      };
    }

    try {
      final res = await _api.get(ApiConstants.featuredPublications);
      final data = res.data as Map<String, dynamic>;
      await _storage.setWithTTL(cacheKey, data, ttl: _ttlFeatured);
      return {
        'featured': (data['featured'] as List? ?? [])
            .map((j) => Publication.fromJson(_safeMap(j)))
            .toList(),
        'trending': (data['trending'] as List? ?? [])
            .map((j) => Publication.fromJson(_safeMap(j)))
            .toList(),
      };
    } catch (e) {
      final stale = _storage.get('cache_$cacheKey');
      if (stale != null && stale is Map && stale['data'] is Map) {
        final data = _safeMap(stale['data']);
        return {
          'featured': (data['featured'] as List? ?? [])
              .map((j) => Publication.fromJson(_safeMap(j)))
              .toList(),
          'trending': (data['trending'] as List? ?? [])
              .map((j) => Publication.fromJson(_safeMap(j)))
              .toList(),
        };
      }
      rethrow;
    }
  }

  void _refreshFeaturedInBackground() {
    if (_refreshing.contains('featured')) return;
    _refreshing.add('featured');
    _api.get(ApiConstants.featuredPublications).then((res) async {
      final data = res.data as Map<String, dynamic>;
      await _storage.setWithTTL('featured_publications', data, ttl: _ttlFeatured);
    }).catchError((_) {}).whenComplete(() => _refreshing.remove('featured'));
  }

  Future<Map<String, dynamic>> featurePublication(
    int id, {
    required int days,
    required String mode,
    String phone = '',
  }) async {
    final res = await _api.post(
      ApiConstants.featurePublication(id),
      data: {
        'days': days,
        'mode_paiement': mode,
        'phone': phone,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyFeaturePayment(
    int id,
    String reference,
  ) async {
    final res = await _api.post(
      ApiConstants.verifyFeaturePayment(id),
      data: {'reference': reference},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getViewsHistory({int days = 14}) async {
    final res = await _api.get(
      'publications/my/views-history/',
      queryParameters: {'days': days},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<List<Publication>> getMyPublications() async {
    const cacheKey = 'my_publications';

    final cached = _storage.getFromCache(cacheKey);
    if (cached != null) {
      final List results = cached is List ? cached : [];
      if (_storage.isCacheStale(cacheKey, gracePeriod: 60)) {
        _api.get(ApiConstants.myPublications).then((res) async {
          final r = res.data['results'] as List? ?? res.data as List? ?? [];
          await _storage.setWithTTL(cacheKey, r, ttl: _ttlMyPubs);
        }).catchError((_) {});
      }
      return results
          .map((j) => Publication.fromJson(_safeMap(j)))
          .toList();
    }

    try {
      final res = await _api.get(ApiConstants.myPublications);
      final results = res.data['results'] as List? ?? res.data as List? ?? [];
      await _storage.setWithTTL(cacheKey, results, ttl: _ttlMyPubs);
      return results
          .map((j) => Publication.fromJson(_safeMap(j)))
          .toList();
    } catch (e) {
      final stale = _storage.get('cache_$cacheKey');
      if (stale != null && stale is Map && stale['data'] is List) {
        final List results = stale['data'];
        return results
            .map((j) => Publication.fromJson(_safeMap(j)))
            .toList();
      }
      rethrow;
    }
  }

  Future<Publication> createPublication(dynamic data) async {
    final res = await _api.post(ApiConstants.createPublication, data: data);
    // Invalider le cache après création
    _storage.delete('cache_my_publications');
    _storage.delete('cache_featured_publications');
    return Publication.fromJson(_safeMap(res.data));
  }

  Future<Publication> updatePublication(int id, dynamic data) async {
    final res = await _api.patch('${ApiConstants.myPublications}$id/', data: data);
    _storage.delete('cache_my_publications');
    _storage.delete('cache_pub_detail_$id');
    return Publication.fromJson(_safeMap(res.data));
  }

  Future<void> deletePublication(int id) async {
    await _api.delete('${ApiConstants.myPublications}$id/');
    _storage.delete('cache_my_publications');
    _storage.delete('cache_pub_detail_$id');
  }

  Future<void> resetPublicationStats(int id) async {
    await _api.post('${ApiConstants.myPublications}$id/reset-stats/');
  }

  /// Upload un fichier média avec retry automatique (pour les réseaux
  /// instables comme au Mali).
  Future<String> uploadMedia(String fileName, {String? filePath, Uint8List? bytes}) async {
    // ── CORRECTIF ANDROID 11+ (Scoped Storage) ───────────────────────────
    // Sur Android 11+, FilePicker retourne parfois des URI content://
    // inaccessibles via dart:io. On essaie de lire les bytes en fallback.
    Uint8List? fileBytes = bytes;
    if (fileBytes == null && filePath != null && filePath.isNotEmpty) {
      try {
        fileBytes = await File(filePath).readAsBytes();
      } catch (_) {
        // Impossible de lire via le chemin — on lève une erreur claire
        throw Exception(
          'Impossible d\'accéder au fichier. '
          'Essayez de sélectionner un fichier plus petit ou depuis les téléchargements.',
        );
      }
    }

    if (fileBytes == null || fileBytes.isEmpty) {
      throw Exception(
        'Fichier vide ou illisible. '
        'Essayez un autre fichier.',
      );
    }

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
    });

    // Retry automatique : 3 tentatives avec backoff exponentiel
    // (0s, 2s, 4s) — critique pour le réseau malien instable
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final res = await _api.post(ApiConstants.mediaUpload, data: formData);
        return _safeMap(res.data)['url']?.toString() ?? '';
      } on DioException catch (e) {
        final isLastAttempt = attempt == 2;
        final isRetryable = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError ||
            (e.response?.statusCode ?? 0) >= 500;

        if (isLastAttempt || !isRetryable) rethrow;

        // Backoff exponentiel : 0s, 2s, 4s
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
    throw Exception('Upload échoué après 3 tentatives');
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    const cacheKey = 'categories';

    final cached = _storage.getFromCache(cacheKey);
    if (cached != null) {
      return _safeMapList(cached);
    }

    try {
      final res = await _api.get('${ApiConstants.publications}categories/');
      final results = res.data['results'] as List? ?? res.data as List? ?? [];
      final casted = _safeMapList(results);
      // TTL long (1h) car les catégories changent rarement
      await _storage.setWithTTL(cacheKey, casted, ttl: _ttlCategories);
      return casted;
    } catch (e) {
      final stale = _storage.get('cache_$cacheKey');
      if (stale != null && stale is Map && stale['data'] is List) {
        return _safeMapList(stale['data']);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createCategory(String name) async {
    final res = await _api.post(
      '${ApiConstants.publications}categories/',
      data: {'name': name},
    );
    _storage.delete('cache_categories');
    return res.data as Map<String, dynamic>;
  }

  Future<List<ConversationMessage>> getConversationFeed(
      int publicationId) async {
    final cacheKey = 'conversation_feed_$publicationId';

    final cached = _storage.getFromCache(cacheKey);
    if (cached != null) {
      final List results = cached is List ? cached : [];
      return results
          .map((j) => ConversationMessage.fromJson(_safeMap(j)))
          .toList();
    }

    try {
      final res = await _api.get(ApiConstants.conversationFeed(publicationId));
      final results = res.data as List? ?? [];
      await _storage.setWithTTL(cacheKey, results, ttl: _ttlDetail);
      return results
          .map((j) => ConversationMessage.fromJson(_safeMap(j)))
          .toList();
    } catch (e) {
      final stale = _storage.get('cache_$cacheKey');
      if (stale != null && stale is Map && stale['data'] is List) {
        return (stale['data'] as List)
            .map((j) => ConversationMessage.fromJson(_safeMap(j)))
            .toList();
      }
      rethrow;
    }
  }

  Future<void> postComment(
    int publicationId, {
    required String text,
    String? parentId,
  }) async {
    int? parentCommentId;
    if (parentId != null && parentId.startsWith('comment-')) {
      parentCommentId = int.tryParse(parentId.substring('comment-'.length));
    }
    await _api.post(
      ApiConstants.commentAdd(publicationId),
      data: {
        'text': text,
        if (parentCommentId != null) 'parent': parentCommentId,
      },
    );
    _storage.delete('cache_conversation_feed_$publicationId');
  }

  Future<void> deleteComment(String messageId) async {
    if (!messageId.startsWith('comment-')) return;
    final id = int.tryParse(messageId.substring('comment-'.length));
    if (id == null) return;
    await _api.delete(ApiConstants.commentDelete(id));
  }

  Future<List<Map<String, dynamic>>> getReviews(int publicationId) async {
    final cacheKey = 'reviews_$publicationId';

    final cached = _storage.getFromCache(cacheKey);
    if (cached != null) {
      return _safeMapList(cached);
    }

    try {
      final res = await _api.get('${ApiConstants.publications}$publicationId/reviews/');
      final results = res.data['results'] as List? ?? res.data as List? ?? [];
      final casted = _safeMapList(results);
      await _storage.setWithTTL(cacheKey, casted, ttl: _ttlDetail);
      return casted;
    } catch (e) {
      final stale = _storage.get('cache_$cacheKey');
      if (stale != null && stale is Map && stale['data'] is List) {
        return _safeMapList(stale['data']);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> postReview(
    int publicationId, {
    required String comment,
    int rating = 5,
  }) async {
    final res = await _api.post(
      '${ApiConstants.publications}$publicationId/reviews/add/',
      data: {'comment': comment, 'rating': rating},
    );
    _storage.delete('cache_reviews_$publicationId');
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getPublicPublishers() async {
    const cacheKey = 'public_publishers';

    final cached = _storage.getFromCache(cacheKey);
    if (cached != null) {
      return _safeMapList(cached);
    }

    try {
      final res = await _api.get(ApiConstants.publicPublishers);
      final results = res.data['results'] as List? ?? res.data as List? ?? [];
      final casted = _safeMapList(results);
      await _storage.setWithTTL(cacheKey, casted, ttl: _ttlProfile);
      return casted;
    } catch (e) {
      final stale = _storage.get('cache_$cacheKey');
      if (stale != null && stale is Map && stale['data'] is List) {
        return _safeMapList(stale['data']);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getPublicPublisherProfile(
      int publisherId) async {
    final cacheKey = 'public_publisher_profile_$publisherId';

    final cached = _storage.getFromCache(cacheKey);
    if (cached != null) {
      if (_storage.isCacheStale(cacheKey, gracePeriod: 120)) {
        _api.get(ApiConstants.publicPublisherDetail(publisherId)).then((res) async {
          await _storage.setWithTTL(cacheKey, res.data, ttl: _ttlProfile);
        }).catchError((_) {});
      }
      return _safeMap(cached);
    }

    try {
      final res = await _api.get(ApiConstants.publicPublisherDetail(publisherId));
      await _storage.setWithTTL(cacheKey, res.data, ttl: _ttlProfile);
      return res.data as Map<String, dynamic>;
    } catch (e) {
      final stale = _storage.get('cache_$cacheKey');
      if (stale != null && stale is Map) {
        return _safeMap(stale['data']);
      }
      rethrow;
    }
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
  final Ref _ref;
  int _loadSeq = 0;

  PublicationListNotifier(this._service, this._ref) : super(const PublicationListState()) {
    _ref.listen(realtimeEventProvider, (previous, next) {
      if (next != null) {
        final ev = next.event;
        if (ev == 'publication_published' ||
            ev == 'stats_changed' ||
            ev == 'payment_success' ||
            ev == 'transaction_updated' ||
            ev == 'abonnement_updated' ||
            ev == 'favorites_updated') {
          // Rechargement silencieux en arrière-plan sans bloquer l'UI
          load(refresh: true, silent: true);
          _ref.invalidate(featuredProvider);
          _ref.invalidate(categoriesProvider);
        }
      }
    });
  }

  Future<void> load({
    bool refresh = false,
    bool silent = false,
    String? search,
    String? category,
    String? type,
    bool? isFree,
    int? publisherId,
  }) async {
    final pageToLoad = refresh ? 1 : state.currentPage;
    if (!refresh && (!state.hasMore || state.isLoading)) return;

    final seq = ++_loadSeq;
    if (!silent) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final items = await _service.getPublications(
        page: pageToLoad,
        search: search,
        category: category,
        type: type,
        isFree: isFree,
        publisherId: publisherId,
      );
      if (seq != _loadSeq) return;
      if (refresh) {
        state = PublicationListState(
          items: items,
          isLoading: false,
          hasMore: items.isNotEmpty,
          currentPage: 2,
        );
      } else {
        if (items.isEmpty) {
          state = state.copyWith(isLoading: false, hasMore: false);
        } else {
          state = state.copyWith(
            items: [...state.items, ...items],
            isLoading: false,
            currentPage: state.currentPage + 1,
          );
        }
      }
    } catch (e) {
      if (seq != _loadSeq) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

final publicationListProvider =
    StateNotifierProvider<PublicationListNotifier, PublicationListState>((ref) {
  final service = ref.watch(publicationServiceProvider);
  return PublicationListNotifier(service, ref);
});

final publicPublishersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(publicationServiceProvider);
  return service.getPublicPublishers();
});

final featuredProvider =
    FutureProvider<Map<String, List<Publication>>>((ref) async {
  final service = ref.watch(publicationServiceProvider);
  return service.getFeatured();
});

final publicPublisherProfileProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, publisherId) async {
  final service = ref.watch(publicationServiceProvider);
  return service.getPublicPublisherProfile(publisherId);
});

final myPublicationsProvider = FutureProvider<List<Publication>>((ref) async {
  final service = ref.watch(publicationServiceProvider);
  return service.getMyPublications();
});

final viewsHistoryProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final service = ref.watch(publicationServiceProvider);
  return service.getViewsHistory();
});

final publicationDetailProvider =
    FutureProvider.family<Publication, int>((ref, id) async {
  final service = ref.watch(publicationServiceProvider);
  return service.getPublication(id);
});

final reviewsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, int>((ref, publicationId) async {
  final service = ref.watch(publicationServiceProvider);
  return service.getReviews(publicationId);
});

final conversationFeedProvider = FutureProvider.autoDispose
    .family<List<ConversationMessage>, int>((ref, publicationId) async {
  final service = ref.watch(publicationServiceProvider);
  return service.getConversationFeed(publicationId);
});

final categoriesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(publicationServiceProvider);
  return service.getCategories();
});

final publisherPublicationsListProvider = StateNotifierProvider<
    PublisherPublicationsListNotifier, AsyncValue<List<Publication>>>((ref) {
  final service = ref.watch(publicationServiceProvider);
  return PublisherPublicationsListNotifier(service, ref);
});

class PublisherPublicationsListNotifier
    extends StateNotifier<AsyncValue<List<Publication>>> {
  final PublicationService _service;
  final Ref _ref;

  PublisherPublicationsListNotifier(this._service, this._ref)
      : super(const AsyncValue.loading()) {
    loadMyPublications();
    _ref.listen(realtimeEventProvider, (previous, next) {
      if (next != null && next.event == 'stats_changed') {
        loadMyPublications();
      }
    });
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

  Future<void> createPublication(dynamic data) async {
    try {
      final newPub = await _service.createPublication(data);
      state.whenData((list) {
        state = AsyncValue.data([newPub, ...list]);
      });
      _ref.read(publicationListProvider.notifier).load(refresh: true);
      _ref.invalidate(featuredProvider);
      _ref.invalidate(categoriesProvider);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updatePublication(int id, dynamic data) async {
    try {
      final updated = await _service.updatePublication(id, data);
      state.whenData((list) {
        state =
            AsyncValue.data(list.map((p) => p.id == id ? updated : p).toList());
      });
      _ref.read(publicationListProvider.notifier).load(refresh: true);
      _ref.invalidate(featuredProvider);
      _ref.invalidate(categoriesProvider);
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

  Future<void> resetStats(int id) async {
    try {
      await _service.resetPublicationStats(id);
      loadMyPublications();
    } catch (e) {
      rethrow;
    }
  }
}
