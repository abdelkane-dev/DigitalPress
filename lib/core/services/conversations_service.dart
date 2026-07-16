import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:digital_press/core/api/api_client.dart';
import 'package:digital_press/config/api_constants.dart';

final conversationsServiceProvider = Provider<ConversationsService>((ref) {
  final api = ref.watch(apiClientProvider);
  return ConversationsService(api);
});

final conversationReviewsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>(
        (ref, publicationId) async {
  final svc = ref.watch(conversationsServiceProvider);
  return svc.getPublicationReviews(publicationId);
});

class ConversationsService {
  final ApiClient _api;
  ConversationsService(this._api);

  Future<List<Map<String, dynamic>>> getConversations() async {
    final res = await _api.get('${ApiConstants.publications}conversations/');
    final results = res.data as List? ?? res.data['results'] as List? ?? [];
    return results.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getPublicationReviews(
      int publicationId) async {
    final res = await _api
        .get(ApiConstants.conversationFeed(publicationId));
    final results = res.data as List? ?? res.data['results'] as List? ?? [];
    return results.cast<Map<String, dynamic>>();
  }

  Future<void> markRead(int publicationId) async {
    await _api
        .post('${ApiConstants.publications}conversations/$publicationId/read/');
  }

  Future<void> hideConversation(int publicationId) async {
    await _api
        .post('${ApiConstants.publications}conversations/$publicationId/hide/');
  }
}
