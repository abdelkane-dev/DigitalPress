import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:digital_press/core/services/conversations_service.dart';
import 'package:digital_press/screens/conversations/conversation_detail_screen.dart';

final conversationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final svc = ref.watch(conversationsServiceProvider);
  return svc.getConversations();
});

class ConversationsListScreen extends ConsumerStatefulWidget {
  const ConversationsListScreen({super.key});

  @override
  ConsumerState<ConversationsListScreen> createState() =>
      _ConversationsListScreenState();
}

class _ConversationsListScreenState
    extends ConsumerState<ConversationsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final convAsync = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Conversations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(conversationsProvider),
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: convAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Erreur : $e')),
        data: (list) {
          final filtered = _filterConversations(list, _searchQuery);

          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher une conversation...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.refresh(conversationsProvider);
                    await ref.read(conversationsProvider.future);
                  },
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text('Aucune conversation trouvée'),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final title = item['title']?.toString() ?? '—';
                            final subtitle =
                                item['last_comment_text']?.toString() ?? '';
                            final unread = (item['unread_count'] as int?) ?? 0;
                            final totalComments =
                                (item['total_comments'] as int?) ?? 0;
                            final date = _formatDate(
                                item['last_comment_at']?.toString());
                            final category =
                                item['category']?['name']?.toString() ?? '';

                            return Dismissible(
                              key: ValueKey(item['id']),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                alignment: Alignment.centerRight,
                                color: Colors.red.shade700,
                                child: const Icon(
                                  Icons.hide_source_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              confirmDismiss: (_) async {
                                final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text(
                                            'Masquer la conversation'),
                                        content: const Text(
                                            'Cette conversation sera masquée de la liste. Continuer ?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context)
                                                    .pop(false),
                                            child: const Text('Annuler'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text('Masquer'),
                                          ),
                                        ],
                                      ),
                                    ) ??
                                    false;
                                if (confirmed) {
                                  await ref
                                      .read(conversationsServiceProvider)
                                      .hideConversation(item['id'] as int);
                                  ref.refresh(conversationsProvider);
                                }
                                return confirmed;
                              },
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue.shade700,
                                  child: Text(
                                    title.isNotEmpty
                                        ? title[0].toUpperCase()
                                        : 'C',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (category.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          category,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        subtitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: TextButton.icon(
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          backgroundColor: Colors.blue.shade50,
                                          foregroundColor: Colors.blue.shade800,
                                          textStyle: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.chat_bubble_outline,
                                          size: 16,
                                        ),
                                        label: const Text('Commenter'),
                                        onPressed: () async {
                                          await ref
                                              .read(
                                                  conversationsServiceProvider)
                                              .markRead(item['id'] as int);
                                          ref.refresh(conversationsProvider);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ConversationDetailScreen(
                                                publicationId:
                                                    item['id'] as int,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (unread > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade600,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$unread',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      '$date · $totalComments commentaire(s)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () async {
                                  await ref
                                      .read(conversationsServiceProvider)
                                      .markRead(item['id'] as int);
                                  ref.refresh(conversationsProvider);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ConversationDetailScreen(
                                        publicationId: item['id'] as int,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _filterConversations(
      List<Map<String, dynamic>> list, String query) {
    if (query.isEmpty) return list;
    return list.where((item) {
      final title = item['title']?.toString().toLowerCase() ?? '';
      final comment = item['last_comment_text']?.toString().toLowerCase() ?? '';
      final q = query.toLowerCase();
      return title.contains(q) || comment.contains(q);
    }).toList();
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return '—';
    }
    final date = DateTime.tryParse(dateString);
    if (date == null) return '—';
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays == 0) {
      return 'Aujourd’hui';
    }
    if (difference.inDays == 1) {
      return 'Hier';
    }
    if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} jours';
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}
