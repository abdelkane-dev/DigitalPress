import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:digital_press/core/api/api_client.dart';
import 'package:digital_press/config/api_constants.dart';
import 'package:digital_press/model/feature_item.dart';

final roadmapServiceProvider = Provider<RoadmapService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RoadmapService(apiClient);
});

class RoadmapService {
  final ApiClient _api;
  RoadmapService(this._api);

  Future<List<FeatureItem>> getFeatures({String? status}) async {
    final res = await _api.get(
      ApiConstants.roadmap,
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    final raw = res.data;
    final List<dynamic> results = raw is Map
        ? (raw['results'] as List? ?? [])
        : (raw as List? ?? []);
    return results
        .map((j) => FeatureItem.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<FeatureItem> createFeature({
    required String title,
    required String description,
    String? scope,
  }) async {
    final res = await _api.post(ApiConstants.roadmap, data: {
      'title': title,
      'description': description,
      if (scope != null) 'scope': scope,
    });
    return FeatureItem.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> updateStatus(int id, String status) async {
    await _api.patch(ApiConstants.roadmapStatus(id), data: {'status': status});
  }

  Future<void> deleteFeature(int id) async {
    await _api.delete(ApiConstants.roadmapDelete(id));
  }
}

final roadmapListProvider =
    FutureProvider.autoDispose<List<FeatureItem>>((ref) async {
  final service = ref.watch(roadmapServiceProvider);
  return service.getFeatures();
});
