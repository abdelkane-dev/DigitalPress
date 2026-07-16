import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:digital_press/core/api/api_client.dart';
import 'package:digital_press/config/api_constants.dart';
import 'package:digital_press/model/conversation.dart';

final conversationServiceProvider = Provider<ConversationService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ConversationService(apiClient);
});

class ConversationService {
  final ApiClient _api;
  ConversationService(this._api);

  Future<List<Conversation>> getConversations({String? search}) async {
    final res = await _api.get(
      ApiConstants.conversations,
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final results = res.data as List? ?? [];
    return results
        .map((j) => Conversation.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Marque la conversation comme lue (appelé quand l'utilisateur ouvre
  /// l'article pour lire les commentaires).
  Future<void> markAsRead(int articleId) async {
    await _api.post(ApiConstants.conversationMarkRead(articleId));
  }

  /// "Quitte" la conversation : elle disparaît de la liste sans supprimer
  /// les commentaires de l'utilisateur.
  Future<void> hide(int articleId) async {
    await _api.post(ApiConstants.conversationHide(articleId));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// État de la liste des conversations (Riverpod StateNotifier)
// ─────────────────────────────────────────────────────────────────────────────

class ConversationListState {
  final List<Conversation> items;
  final bool isLoading;
  final String? error;

  const ConversationListState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  ConversationListState copyWith({
    List<Conversation>? items,
    bool? isLoading,
    String? error,
  }) {
    return ConversationListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ConversationListNotifier extends StateNotifier<ConversationListState> {
  final ConversationService _service;

  ConversationListNotifier(this._service) : super(const ConversationListState());

  Future<void> load({String? search}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await _service.getConversations(search: search);
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Marque une conversation comme lue localement (badge retiré tout de
  /// suite dans l'UI, sans attendre un rechargement complet).
  void markReadLocally(int articleId) {
    state = state.copyWith(
      items: state.items
          .map((c) => c.articleId == articleId
              ? c.copyWith(hasNewComments: false, newCommentsCount: 0)
              : c)
          .toList(),
    );
  }

  Future<void> markAsRead(int articleId) async {
    markReadLocally(articleId);
    try {
      await _service.markAsRead(articleId);
    } catch (_) {
      // L'échec silencieux du "marquer comme lu" ne doit pas bloquer la
      // lecture de l'article ; on retentera au prochain chargement.
    }
  }

  Future<void> hide(int articleId) async {
    final previous = state.items;
    state = state.copyWith(
      items: previous.where((c) => c.articleId != articleId).toList(),
    );
    try {
      await _service.hide(articleId);
    } catch (e) {
      // On restaure la liste si le serveur a refusé la demande.
      state = state.copyWith(items: previous, error: e.toString());
      rethrow;
    }
  }
}

final conversationListProvider =
    StateNotifierProvider<ConversationListNotifier, ConversationListState>((ref) {
  final service = ref.watch(conversationServiceProvider);
  return ConversationListNotifier(service);
});
