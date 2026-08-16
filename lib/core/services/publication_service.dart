import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:digital_press/core/api/api_client.dart';
import 'package:digital_press/config/api_constants.dart';
import 'package:digital_press/model/publication.dart';
import 'package:digital_press/model/conversation_message.dart';
import 'package:digital_press/core/storage/storage_service.dart';
import 'app_notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Service Publication (Riverpod)
// Remplace ContenuService + ancienne ContenuProvider (ChangeNotifier)
// ─────────────────────────────────────────────────────────────────────────────

final publicationServiceProvider = Provider<PublicationService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storageService = ref.watch(storageServiceProvider);
  return PublicationService(apiClient, storageService);
});

class PublicationService {
  final ApiClient _api;
  final StorageService _storage;
  PublicationService(this._api, this._storage);

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
    try {
      final res =
          await _api.get(ApiConstants.publications, queryParameters: params);
      final results = res.data['results'] as List? ?? res.data as List? ?? [];
      await _storage.set(cacheKey, jsonEncode(results));
      return results
          .map((j) => Publication.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      final cachedData = _storage.get(cacheKey);
      if (cachedData != null) {
        final List results = jsonDecode(cachedData as String) as List;
        return results
            .map((j) => Publication.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
  }

  Future<Publication> getPublication(int id) async {
    final cacheKey = 'pub_detail_$id';
    try {
      final res = await _api.get('${ApiConstants.publications}$id/');
      await _storage.set(cacheKey, jsonEncode(res.data));
      return Publication.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      final cachedData = _storage.get(cacheKey);
      if (cachedData != null) {
        return Publication.fromJson(
            jsonDecode(cachedData as String) as Map<String, dynamic>);
      }
      rethrow;
    }
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

  /// Résultat de la vitrine « À la une » de l'accueil : mises en avant
  /// (payantes ou manuelles) + tendances (fort nombre de vues récentes).
  Future<Map<String, List<Publication>>> getFeatured() async {
    const cacheKey = 'featured_publications';
    try {
      final res = await _api.get(ApiConstants.featuredPublications);
      final data = res.data as Map<String, dynamic>;
      final result = <String, List<Publication>>{
        'featured': (data['featured'] as List? ?? [])
            .map((j) => Publication.fromJson(j as Map<String, dynamic>))
            .toList(),
        'trending': (data['trending'] as List? ?? [])
            .map((j) => Publication.fromJson(j as Map<String, dynamic>))
            .toList(),
      };
      await _storage.set(cacheKey, jsonEncode(data));
      return result;
    } catch (e) {
      final cachedData = _storage.get(cacheKey);
      if (cachedData != null) {
        final data = jsonDecode(cachedData as String) as Map<String, dynamic>;
        return {
          'featured': (data['featured'] as List? ?? [])
              .map((j) => Publication.fromJson(j as Map<String, dynamic>))
              .toList(),
          'trending': (data['trending'] as List? ?? [])
              .map((j) => Publication.fromJson(j as Map<String, dynamic>))
              .toList(),
        };
      }
      rethrow;
    }
  }

  /// Met une publication « À la une » en payant (façon publicité Facebook).
  /// [days] : 7, 14 ou 30 jours. [mode] : 'wallet' (solde éditeur) ou
  /// 'simulation'/'cinetpay' (mobile money). Retourne le payload serveur
  /// (transaction, payment_url…).
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

  /// Vérifie le paiement mobile money d'une mise en avant puis l'active.
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

  /// Historique des vues jour par jour des publications de l'éditeur
  /// connecté (basé sur le modèle PublicationView côté backend).
  Future<Map<String, dynamic>> getViewsHistory({int days = 14}) async {
    final res = await _api.get(
      'publications/my/views-history/',
      queryParameters: {'days': days},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<List<Publication>> getMyPublications() async {
    const cacheKey = 'my_publications';
    try {
      final res = await _api.get(ApiConstants.myPublications);
      final results = res.data['results'] as List? ?? res.data as List? ?? [];
      await _storage.set(cacheKey, jsonEncode(results));
      return results
          .map((j) => Publication.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      final cachedData = _storage.get(cacheKey);
      if (cachedData != null) {
        final List results = jsonDecode(cachedData as String) as List;
        return results
            .map((j) => Publication.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
  }

  Future<Publication> createPublication(dynamic data) async {
    final res = await _api.post(ApiConstants.createPublication, data: data);
    return Publication.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Publication> updatePublication(
      int id, dynamic data) async {
    final res =
        await _api.patch('${ApiConstants.myPublications}$id/', data: data);
    return Publication.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deletePublication(int id) async {
    await _api.delete('${ApiConstants.myPublications}$id/');
  }

  /// Remet à zéro les compteurs (vues, téléchargements) d'une publication
  /// de l'éditeur connecté — l'éditeur repart d'une page blanche.
  Future<void> resetPublicationStats(int id) async {
    await _api.post('${ApiConstants.myPublications}$id/reset-stats/');
  }

  /// Upload un fichier média (image, PDF, vidéo) sur le serveur.
  /// Retourne l'URL absolue du fichier accessible publiquement.
  Future<String> uploadMedia(String fileName, {String? filePath, Uint8List? bytes}) async {
    final formData = FormData.fromMap({
      'file': bytes != null
          ? MultipartFile.fromBytes(bytes, filename: fileName)
          : await MultipartFile.fromFile(filePath!, filename: fileName),
    });
    final res = await _api.post(ApiConstants.mediaUpload, data: formData);
    return (res.data as Map<String, dynamic>)['url']?.toString() ?? '';
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    const cacheKey = 'categories';
    try {
      final res = await _api.get('${ApiConstants.publications}categories/');
      final results = res.data['results'] as List? ?? res.data as List? ?? [];
      final casted = results.cast<Map<String, dynamic>>();
      await _storage.set(cacheKey, jsonEncode(casted));
      return casted;
    } catch (e) {
      final cachedData = _storage.get(cacheKey);
      if (cachedData != null) {
        final List decoded = jsonDecode(cachedData as String) as List;
        return decoded.cast<Map<String, dynamic>>();
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createCategory(String name) async {
    final res = await _api.post(
      '${ApiConstants.publications}categories/',
      data: {'name': name},
    );
    return res.data as Map<String, dynamic>;
  }

  /// Le fil complet de la conversation d'un article : avis notés par
  /// étoiles + réponses libres façon commentaires Facebook, triés
  /// chronologiquement.
  Future<List<ConversationMessage>> getConversationFeed(
      int publicationId) async {
    final cacheKey = 'conversation_feed_$publicationId';
    try {
      final res = await _api.get(ApiConstants.conversationFeed(publicationId));
      final results = res.data as List? ?? [];
      await _storage.set(cacheKey, jsonEncode(results));
      return results
          .map((j) => ConversationMessage.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      final cachedData = _storage.get(cacheKey);
      if (cachedData != null) {
        final List results = jsonDecode(cachedData as String) as List;
        return results
            .map((j) => ConversationMessage.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
  }

  /// Poste une réponse libre. [parentId] est l'id complet du message auquel
  /// on répond (ex: "comment-45") — laisser à null pour un message de
  /// premier niveau dans la conversation.
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
  }

  /// Supprime un commentaire (l'auteur ou un admin uniquement). [messageId]
  /// est l'id complet (ex: "comment-45") ; ignoré silencieusement s'il
  /// s'agit d'un avis (type "review", non supprimable ici).
  Future<void> deleteComment(String messageId) async {
    if (!messageId.startsWith('comment-')) return;
    final id = int.tryParse(messageId.substring('comment-'.length));
    if (id == null) return;
    await _api.delete(ApiConstants.commentDelete(id));
  }

  /// Liste des commentaires (avis) d'un article, du plus récent au plus
  /// ancien — c'est cette liste qui forme la "conversation" de l'article.
  Future<List<Map<String, dynamic>>> getReviews(int publicationId) async {
    final cacheKey = 'reviews_$publicationId';
    try {
      final res =
          await _api.get('${ApiConstants.publications}$publicationId/reviews/');
      final results = res.data as List? ?? res.data['results'] as List? ?? [];
      final casted = results.cast<Map<String, dynamic>>();
      await _storage.set(cacheKey, jsonEncode(casted));
      return casted;
    } catch (e) {
      final cachedData = _storage.get(cacheKey);
      if (cachedData != null) {
        final List decoded = jsonDecode(cachedData as String) as List;
        return decoded.cast<Map<String, dynamic>>();
      }
      rethrow;
    }
  }

  /// Poste un commentaire sur un article. Si l'utilisateur a déjà commenté
  /// cet article, son commentaire existant est mis à jour (un seul message
  /// par utilisateur et par article, modifiable à tout moment).
  Future<Map<String, dynamic>> postReview(
    int publicationId, {
    required String comment,
    int rating = 5,
  }) async {
    final res = await _api.post(
      '${ApiConstants.publications}$publicationId/reviews/add/',
      data: {'comment': comment, 'rating': rating},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getPublicPublishers() async {
    const cacheKey = 'public_publishers';
    try {
      final res = await _api.get(ApiConstants.publicPublishers);
      final results = res.data as List? ?? [];
      final casted = results.cast<Map<String, dynamic>>();
      await _storage.set(cacheKey, jsonEncode(casted));
      return casted;
    } catch (e) {
      final cachedData = _storage.get(cacheKey);
      if (cachedData != null) {
        final List decoded = jsonDecode(cachedData as String) as List;
        return decoded.cast<Map<String, dynamic>>();
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getPublicPublisherProfile(
      int publisherId) async {
    final cacheKey = 'public_publisher_profile_$publisherId';
    try {
      final res = await _api.get(ApiConstants.publicPublisherDetail(publisherId));
      await _storage.set(cacheKey, jsonEncode(res.data));
      return res.data as Map<String, dynamic>;
    } catch (e) {
      final cachedData = _storage.get(cacheKey);
      if (cachedData != null) {
        return jsonDecode(cachedData as String) as Map<String, dynamic>;
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

  /// Numéro de séquence de la dernière requête lancée. Permet d'ignorer
  /// une réponse obsolète (ex: l'utilisateur a tapé une nouvelle recherche
  /// pendant qu'une ancienne requête était encore en vol) — sans ce garde,
  /// la réponse la plus lente écrasait le résultat de la plus récente,
  /// affichant des résultats qui ne correspondent pas à la recherche.
  int _loadSeq = 0;

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

    final seq = ++_loadSeq;
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
      // Une requête plus récente a été lancée entre-temps : on jette cette
      // réponse pour ne pas écraser l'affichage le plus à jour.
      if (seq != _loadSeq) return;
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
      if (seq != _loadSeq) return;
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

/// Vitrine « À la une » de l'accueil : {featured: [...], trending: [...]}.
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

/// Historique des vues de l'éditeur (série journalière + par publication).
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
    // Statistiques éditeur en temps réel : nouvelle vue, nouveau
    // commentaire, nouvelle transaction... rechargent automatiquement la
    // liste (et donc les stats qui en dérivent, voir
    // poster_statistics_screen.dart) sans action de l'utilisateur.
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
      // Invalider et recharger immédiatement la liste publique de l'accueil
      _ref.read(publicationListProvider.notifier).load(refresh: true);
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
