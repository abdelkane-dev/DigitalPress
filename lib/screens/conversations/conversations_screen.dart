import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/conversation_service.dart';
import '../../model/conversation.dart';
import '../../widgets/main_app_bar.dart';

/// Page "Mes Conversations" : remplace l'ancienne page "Favoris".
/// Affiche, pour l'utilisateur connecté (Admin, Éditeur ou Lecteur — cette
/// page est strictement identique pour tous les rôles), la liste des
/// articles où il a laissé au moins un commentaire, façon liste de
/// discussions WhatsApp/Telegram : la plus récente en haut, un badge rouge
/// pour les nouveaux commentaires non lus, et un appui long ou un swipe
/// pour quitter la conversation.
class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(conversationListProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openConversation(Conversation conversation) async {
    // Marque comme lue immédiatement (le badge disparaît tout de suite),
    // puis redirige vers l'article, scrollé directement sur les commentaires.
    await ref.read(conversationListProvider.notifier).markAsRead(conversation.articleId);
    if (!mounted) return;
    context.push('/article/${conversation.articleId}?scrollToComments=true');
  }

  Future<void> _confirmLeave(Conversation conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Quitter la conversation ?'),
        content: Text(
          'L\'article "${conversation.title}" sera retiré de votre liste "Mes Conversations". '
          'Vos commentaires ne seront pas supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(conversationListProvider.notifier).hide(conversation.articleId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conversation retirée de votre liste.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationListProvider);
    final query = _searchController.text.trim().toLowerCase();
    final items = query.isEmpty
        ? state.items
        : state.items.where((c) => c.title.toLowerCase().contains(query)).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => ref.read(conversationListProvider.notifier).load(),
        child: CustomScrollView(
          slivers: [
            MainAppBar(
              title: 'Conversations',
              titleBadge: state.items.where((c) => c.hasNewComments).isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${state.items.where((c) => c.hasNewComments).length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    )
                  : null,
              extraAction: Container(
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                    color: const Color(0xFF0A2647),
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _isGridView = !_isGridView;
                    });
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildSearchBar()),
            if (state.isLoading && state.items.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (state.error != null && state.items.isEmpty)
              SliverToBoxAdapter(child: _buildError(state.error!))
            else if (items.isEmpty)
              _buildEmptyState(query.isNotEmpty)
            else if (_isGridView)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.95,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildConversationCard(items[index]),
                    childCount: items.length,
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildConversationTile(items[index]),
                  childCount: items.length,
                ),
              ),
          ],
        ),
      ),
    );
  }


  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.black87),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Rechercher une conversation...',
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF336B82)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: Colors.grey.shade400),
                  onPressed: () => setState(() => _searchController.clear()),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Text('Erreur : $error', textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isSearchEmpty) {
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.forum_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isSearchEmpty ? 'Aucun résultat' : 'Aucune conversation',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isSearchEmpty
                    ? 'Aucune conversation ne correspond à votre recherche.'
                    : 'Commentez un article pour démarrer une conversation :\nelle apparaîtra ici automatiquement.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationTile(Conversation conversation) {
    final initial = conversation.title.isNotEmpty
        ? conversation.title.substring(0, 1).toUpperCase()
        : '?';

    return Dismissible(
      key: ValueKey(conversation.articleId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _confirmLeave(conversation);
        return false; // La suppression réelle passe par le provider, pas par le widget.
      },
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.exit_to_app_rounded, color: Colors.white, size: 28),
      ),
      child: InkWell(
        onTap: () => _openConversation(conversation),
        onLongPress: () => _confirmLeave(conversation),
        child: Container(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
          ),
          child: Row(
            children: [
              // "Photo de profil" = première lettre du titre de l'article.
              Stack(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF2C74B3), Color(0xFF0A2647)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (conversation.hasNewComments)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.shade700,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: conversation.hasNewComments
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(conversation.lastCommentDate),
                          style: TextStyle(
                            fontSize: 11,
                            color: conversation.hasNewComments
                                ? const Color(0xFF336B82)
                                : Colors.grey.shade500,
                            fontWeight: conversation.hasNewComments
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${conversation.lastCommentAuthor.isNotEmpty ? '${conversation.lastCommentAuthor}: ' : ''}'
                            '${conversation.lastCommentText}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: conversation.hasNewComments
                                  ? Colors.black87
                                  : Colors.grey.shade600,
                              fontWeight: conversation.hasNewComments
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${conversation.totalComments}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 12, color: Colors.grey.shade400),
                        if (conversation.hasNewComments) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${conversation.newCommentsCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationCard(Conversation conversation) {
    final initial = conversation.title.isNotEmpty
        ? conversation.title.substring(0, 1).toUpperCase()
        : '?';

    return GestureDetector(
      onTap: () => _openConversation(conversation),
      onLongPress: () => _confirmLeave(conversation),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF2C74B3), Color(0xFF0A2647)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (conversation.hasNewComments)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.shade700,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    _formatDate(conversation.lastCommentDate),
                    style: TextStyle(
                      fontSize: 10,
                      color: conversation.hasNewComments
                          ? const Color(0xFF336B82)
                          : Colors.grey.shade500,
                      fontWeight: conversation.hasNewComments
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: conversation.hasNewComments
                            ? FontWeight.w900
                            : FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${conversation.lastCommentAuthor.isNotEmpty ? '${conversation.lastCommentAuthor}: ' : ''}'
                      '${conversation.lastCommentText}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: conversation.hasNewComments
                            ? Colors.black87
                            : Colors.grey.shade600,
                        fontWeight: conversation.hasNewComments
                            ? FontWeight.w600
                            : FontWeight.w400,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        '${conversation.totalComments}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 12, color: Colors.grey.shade400),
                    ],
                  ),
                  if (conversation.hasNewComments)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C74B3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Nouveau',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'À l\'instant';
    if (difference.inHours < 1) return 'Il y a ${difference.inMinutes} min';
    if (difference.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} j';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
