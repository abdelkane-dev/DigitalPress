import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:digital_press/core/api/api_client.dart';
import 'package:digital_press/config/api_constants.dart';
import 'package:digital_press/model/reader_category.dart';
import 'package:digital_press/model/favorite_article.dart';

final favoritesServiceProvider = Provider<FavoritesService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return FavoritesService(apiClient);
});

class FavoritesService {
  final ApiClient _api;
  FavoritesService(this._api);

  Future<List<ReaderCategory>> getReaderCategories() async {
    final res = await _api.get(ApiConstants.readerCategories);
    List results;
    if (res.data is Map && res.data['results'] != null) {
      results = res.data['results'] as List;
    } else if (res.data is List) {
      results = res.data as List;
    } else {
      results = [];
    }
    return results.map((j) => ReaderCategory.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<ReaderCategory> createReaderCategory(String name) async {
    final res = await _api.post(ApiConstants.readerCategories, data: {'name': name});
    return ReaderCategory.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteReaderCategory(int id) async {
    await _api.delete(ApiConstants.readerCategoryDelete(id));
  }

  Future<List<FavoriteArticle>> getFavorites({int? categoryId}) async {
    final res = await _api.get(
      ApiConstants.favorites,
      queryParameters: {
        if (categoryId != null) 'category': categoryId,
      },
    );
    List results;
    if (res.data is Map && res.data['results'] != null) {
      results = res.data['results'] as List;
    } else if (res.data is List) {
      results = res.data as List;
    } else {
      results = [];
    }
    return results.map((j) => FavoriteArticle.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Ajoute un article aux favoris (ou met à jour ses catégories s'il y est
  /// déjà). [categoryIds] peut être vide : l'article reste favori sans être
  /// rangé dans une playlist précise.
  Future<void> addOrUpdateFavorite(int publicationId, {List<int>? categoryIds}) async {
    await _api.post(ApiConstants.favoriteAdd, data: {
      'publication': publicationId,
      if (categoryIds != null) 'category_ids': categoryIds,
    });
  }

  Future<void> removeFavorite(int publicationId) async {
    await _api.delete(ApiConstants.favoriteRemove(publicationId));
  }
}

final readerCategoriesProvider =
    FutureProvider.autoDispose<List<ReaderCategory>>((ref) async {
  final service = ref.watch(favoritesServiceProvider);
  return service.getReaderCategories();
});

final favoritesProvider =
    FutureProvider.autoDispose.family<List<FavoriteArticle>, int?>((ref, categoryId) async {
  final service = ref.watch(favoritesServiceProvider);
  return service.getFavorites(categoryId: categoryId);
});
