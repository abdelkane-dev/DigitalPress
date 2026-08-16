import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../config/api_config.dart';
import '../../core/storage/secure_storage_service.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/conversation_service.dart';
import '../../core/services/publication_service.dart';
import '../../model/conversation_message.dart';
import '../../model/publication.dart';
import '../../widgets/subscribe_or_buy_sheet.dart';
import '../../widgets/add_to_favorites_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Page complète d'un article : informations, description, bouton de
/// lecture, et conversation en bas de page — façon fil de commentaires
/// Facebook.
///
/// Le premier message que poste un utilisateur dans la conversation est
/// toujours son avis noté par étoiles (widget "Votre avis" épinglé en haut
/// du fil). Une fois cet avis posté, il peut échanger librement avec
/// n'importe qui via des réponses (commentaires), avec possibilité de
/// répondre directement à un message précis (fil de discussion imbriqué).
///
/// Quand [scrollToComments] est vrai (cas d'un clic depuis "Mes
/// Conversations" ou depuis le lecteur d'article), la page s'ouvre
/// directement scrollée tout en bas, sur la discussion en cours.
class ArticleCommentsScreen extends ConsumerStatefulWidget {
  final int articleId;
  final bool scrollToComments;

  const ArticleCommentsScreen({
    super.key,
    required this.articleId,
    this.scrollToComments = false,
  });

  @override
  ConsumerState<ArticleCommentsScreen> createState() => _ArticleCommentsScreenState();
}

class _ArticleCommentsScreenState extends ConsumerState<ArticleCommentsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _commentController = TextEditingController();
  bool _isSending = false;
  ConversationMessage? _replyingTo;
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  Timer? _wsReconnectTimer;

  @override
  void initState() {
    super.initState();
    if (widget.scrollToComments) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
            );
          }
        });
      });
    }
    // On marque la conversation comme lue dès l'ouverture de la page.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(conversationServiceProvider).markAsRead(widget.articleId);
    });
    _connectRealtime();
  }

  /// Conversation en temps réel : dès qu'un autre utilisateur poste un
  /// message dans CETTE conversation, on le reçoit immédiatement et on
  /// invalide juste le provider existant pour refléter l'ajout — pas
  /// besoin de dupliquer la logique d'affichage, on réutilise le
  /// chargement classique déjà en place, juste déclenché instantanément
  /// au lieu d'attendre une action manuelle de l'utilisateur.
  Future<void> _connectRealtime() async {
    final token = await ref.read(secureStorageServiceProvider).getToken();
    if (token == null || token.isEmpty || !mounted) return;

    final base = ApiConfig.wsBaseUrl;
    if (base.isEmpty) return;

    try {
      final uri = Uri.parse('$base/ws/conversations/${widget.articleId}/?token=$token');
      _wsChannel = WebSocketChannel.connect(uri);
      _wsSubscription = _wsChannel!.stream.listen(
        (raw) {
          if (!mounted) return;
          try {
            final decoded = jsonDecode(raw as String);
            if (decoded is Map && decoded['event'] == 'views_updated') {
              // Compteur de vues en direct — pas un nouveau message, donc
              // pas besoin de recharger le fil de conversation pour ça.
              return;
            }
            ref.invalidate(conversationFeedProvider(widget.articleId));
          } catch (_) {
            // Message illisible : on ignore silencieusement, ça ne doit
            // jamais faire planter l'écran de conversation.
          }
        },
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!mounted) return;
    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = Timer(const Duration(seconds: 10), _connectRealtime);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    _wsReconnectTimer?.cancel();
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    super.dispose();
  }

  void _scrollToBottomSoon() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendComment(int publicationId) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    try {
      await ref.read(publicationServiceProvider).postComment(
            publicationId,
            text: text,
            parentId: _replyingTo?.id,
          );
      _commentController.clear();
      setState(() => _replyingTo = null);
      ref.invalidate(conversationFeedProvider(publicationId));
      if (mounted) {
        FocusScope.of(context).unfocus();
        _scrollToBottomSoon();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteMessage(ConversationMessage message, int publicationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer ce message ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(publicationServiceProvider).deleteComment(message.id);
      ref.invalidate(conversationFeedProvider(publicationId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pubAsync = ref.watch(publicationDetailProvider(widget.articleId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Article & conversation'),
        centerTitle: true,
      ),
      body: pubAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (publication) {
          // ─── PAYWALL AVANT LE CONTENU ──────────────────────────────────
          // Un contenu payant non débloqué ne doit RIEN montrer d'autre que
          // les options d'abonnement/achat : ni commentaires, ni avis, ni
          // champ de saisie (demande explicite : « on ne permet aucun
          // visionnage pour les contenus payants sans payer »).
          final user = ref.watch(authServiceProvider).currentUser;
          final locked = publication.isLockedFor(
            currentUserId: user?.id,
            isAdmin: user?.isAdmin ?? false,
          );
          if (locked) return _buildPaywall(publication);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildHeader(publication),
                    const SizedBox(height: 20),
                    _buildMyReviewCard(publication),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 8),
                    _buildConversationThread(publication),
                  ],
                ),
              ),
              _buildCommentInput(publication.id),
            ],
          );
        },
      ),
    );
  }

  /// Écran de verrouillage affiché AVANT tout contenu payant non débloqué
  /// (même habillage que le paywall du lecteur : fond navy, cadenas, bouton
  /// « Débloquer le contenu »). Le texte s'adapte au type de publication.
  Widget _buildPaywall(Publication publication) {
    final isArticle = publication.pubType == 'article';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A2647), Color(0xFF144272)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(Icons.lock_outline_rounded,
                      color: Colors.white, size: 44),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Contenu réservé aux abonnés',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isArticle
                      ? 'Cet article est payant. Abonnez-vous ou achetez-le pour '
                          'lire le contenu et accéder à la conversation.'
                      : 'Vous avez atteint la limite d\'aperçu (3 pages).\n'
                          'Abonnez-vous ou achetez ce numéro pour accéder à '
                          'l\'intégralité du contenu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        showSubscribeOrBuySelection(context, ref, publication),
                    icon: const Icon(Icons.star_rounded),
                    label: const Text('Débloquer le contenu'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C74B3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Publication publication) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (publication.coverImage.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: CachedNetworkImage(
              imageUrl: publication.coverImage,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 200,
                width: double.infinity,
                color: Colors.grey.shade100,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (context, url, error) => const SizedBox.shrink(),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                publication.title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0A2647)),
              ),
            ),
            _buildFavoriteButton(publication),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (publication.categoryName != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C74B3).withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  publication.categoryName!,
                  style: const TextStyle(
                    color: Color(0xFF2C74B3),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            TextButton(
              onPressed: publication.publisherId > 0
                  ? () => context.push('/publisher/${publication.publisherId}')
                  : null,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Par ${publication.publisherName}',
                style: const TextStyle(
                  color: Color(0xFF2C74B3),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          publication.description,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => showSubscribeOrBuySelection(context, ref, publication),
            icon: const Icon(Icons.menu_book_rounded),
            label: const Text('Lire l\'article'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A2647),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  /// Bouton favori : uniquement pour le Lecteur (les catégories
  /// personnelles/playlists sont une fonctionnalité réservée à ce rôle).
  Widget _buildFavoriteButton(Publication publication) {
    final user = ref.watch(authServiceProvider).currentUser;
    if (user == null || !user.isReader) return const SizedBox.shrink();

    return IconButton(
      icon: const Icon(Icons.bookmark_add_outlined, color: Color(0xFF2C74B3)),
      tooltip: 'Ajouter aux favoris',
      onPressed: () => showAddToFavoritesSheet(context, publication),
    );
  }

  Widget _buildMyReviewCard(Publication publication) {
    final reviewsAsync = ref.watch(conversationFeedProvider(publication.id));
    final currentUserId = ref.watch(authServiceProvider).currentUser?.id;

    return reviewsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (messages) {
        ConversationMessage? myReview;
        for (final m in messages) {
          if (m.isReview && m.authorId == currentUserId) {
            myReview = m;
            break;
          }
        }
        return _MyReviewCard(
          publicationId: publication.id,
          existing: myReview,
        );
      },
    );
  }

  Widget _buildConversationThread(Publication publication) {
    final feedAsync = ref.watch(conversationFeedProvider(publication.id));
    final currentUserId = ref.watch(authServiceProvider).currentUser?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.forum_outlined, color: Color(0xFF2C74B3)),
            const SizedBox(width: 8),
            const Text(
              'Conversation',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0A2647)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        feedAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Erreur : $e'),
          ),
          data: (messages) {
            if (messages.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Aucun message pour le moment.\nSoyez le premier à donner votre avis !',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              );
            }

            // Fil chronologique : les avis (étoiles) et les commentaires de
            // premier niveau (sans parent) forment le fil principal ; les
            // réponses sont imbriquées sous leur message parent.
            final byId = {for (final m in messages) m.id: m};
            final repliesByParent = <String, List<ConversationMessage>>{};
            final topLevel = <ConversationMessage>[];
            for (final m in messages) {
              if (m.type == 'comment' && m.parentId != null && byId.containsKey(m.parentId)) {
                repliesByParent.putIfAbsent(m.parentId!, () => []).add(m);
              } else {
                topLevel.add(m);
              }
            }
            topLevel.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            for (final list in repliesByParent.values) {
              list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            }

            return Column(
              children: topLevel
                  .map((m) => _buildMessageWithReplies(
                        m,
                        repliesByParent,
                        currentUserId,
                        publication.id,
                        depth: 0,
                      ))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 80), // Espace pour ne pas être masqué par le champ de saisie.
      ],
    );
  }

  Widget _buildMessageWithReplies(
    ConversationMessage message,
    Map<String, List<ConversationMessage>> repliesByParent,
    String? currentUserId,
    int publicationId, {
    required int depth,
  }) {
    final replies = repliesByParent[message.id] ?? const [];
    return Padding(
      padding: EdgeInsets.only(left: depth * 28.0, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMessageBubble(message, publicationId),
          for (final reply in replies)
            _buildMessageWithReplies(
              reply,
              repliesByParent,
              currentUserId,
              publicationId,
              depth: depth + 1 > 2 ? 2 : depth + 1, // indentation plafonnée
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ConversationMessage message, int publicationId) {
    final isMine = message.isMine;
    final isReview = message.isReview;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isReview
            ? Colors.amber.withAlpha(20)
            : (isMine ? const Color(0xFF2C74B3).withAlpha(20) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isReview
              ? Colors.amber.withAlpha(90)
              : (isMine ? const Color(0xFF2C74B3).withAlpha(60) : Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        isMine ? '${message.authorName} (vous)' : message.authorName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: isMine ? const Color(0xFF0A2647) : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    // ─── AJOUT : badge de compte visible dans les
                    // conversations (Membre Standard/Premium, Super
                    // utilisateur, Compte vérifié) — pour savoir en un
                    // coup d'œil quel type de compte a écrit le message.
                    if (message.authorBadge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          message.authorBadge!,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isReview) ...[
                for (int i = 1; i <= 5; i++)
                  Icon(
                    i <= (message.rating ?? 0) ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 14,
                    color: Colors.amber.shade700,
                  ),
              ],
            ],
          ),
          if (message.text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(message.text, style: const TextStyle(fontSize: 14)),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                _formatDate(message.createdAt),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
              ),
              const Spacer(),
              // ─── CORRECTIF : impossible de répondre à son propre message ──
              // (demande explicite : "pourquoi puis-je me répondre à moi
              // même ? ce n'est pas logique"). Le bouton Répondre n'apparaît
              // plus sur ses propres messages — on peut toujours répondre
              // aux autres et supprimer le sien.
              if (!isReview && !isMine)
                InkWell(
                  onTap: () {
                    setState(() => _replyingTo = message);
                    FocusScope.of(context).requestFocus(FocusNode());
                  },
                  child: Text(
                    'Répondre',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.blue.shade700),
                  ),
                ),
              if (!isReview && isMine) ...[
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => _deleteMessage(message, publicationId),
                  child: Text(
                    'Supprimer',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.red.shade400),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(int publicationId) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingTo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Réponse à ${_replyingTo!.authorName}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _replyingTo = null),
                      child: Icon(Icons.close_rounded, size: 16, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: _replyingTo != null ? 'Écrire une réponse...' : 'Écrire un commentaire...',
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _isSending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send_rounded, color: Color(0xFF2C74B3)),
                        onPressed: () => _sendComment(publicationId),
                      ),
              ],
            ),
          ],
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

/// Carte "Votre avis" : premier message qu'un utilisateur poste dans la
/// conversation, toujours noté par étoiles. Modifiable à tout moment.
class _MyReviewCard extends ConsumerStatefulWidget {
  final int publicationId;
  final ConversationMessage? existing;

  const _MyReviewCard({required this.publicationId, required this.existing});

  @override
  ConsumerState<_MyReviewCard> createState() => _MyReviewCardState();
}

class _MyReviewCardState extends ConsumerState<_MyReviewCard> {
  late int _rating;
  late TextEditingController _textController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.existing?.rating ?? 5;
    _textController = TextEditingController(text: widget.existing?.text ?? '');
  }

  @override
  void didUpdateWidget(covariant _MyReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.existing != null && oldWidget.existing == null) {
      _rating = widget.existing!.rating ?? 5;
      _textController.text = widget.existing!.text;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(publicationServiceProvider).postReview(
            widget.publicationId,
            comment: _textController.text.trim(),
            rating: _rating,
          );
      ref.invalidate(conversationFeedProvider(widget.publicationId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existing == null ? 'Avis publié ! ✓' : 'Avis mis à jour ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasReviewed = widget.existing != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasReviewed ? 'Votre avis' : 'Donnez votre avis pour rejoindre la conversation',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0A2647)),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(5, (index) {
              final starValue = index + 1;
              return IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  starValue <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                  color: Colors.amber.shade700,
                  size: 28,
                ),
                onPressed: () => setState(() => _rating = starValue),
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Votre commentaire (optionnel)',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
              ),
              child: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(hasReviewed ? 'Mettre à jour mon avis' : 'Publier mon avis'),
            ),
          ),
        ],
      ),
    );
  }
}
