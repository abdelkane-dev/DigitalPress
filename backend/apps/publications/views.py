import logging
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Q, Max, Count
from django.shortcuts import get_object_or_404
from django.utils.text import slugify
from .models import (
    Publication, Category, Review, Comment, ConversationRead, HiddenConversation,
    ReaderCategory, Favorite,
)
from .serializers import (
    PublicationSerializer, PublicationCreateSerializer,
    CategorySerializer, ReviewSerializer, ConversationSerializer,
    CommentSerializer, ConversationMessageSerializer,
    ReaderCategorySerializer, FavoritePublicationSerializer,
)

logger = logging.getLogger('apps')
from apps.accounts.permissions import IsAdmin, IsPublisher, IsOwnerOrAdmin, IsReader, IsAdminOrPublisher


class CategoryListView(generics.ListCreateAPIView):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer

    def get_permissions(self):
        if self.request.method == 'POST':
            # Seuls Admin et Éditeur gèrent la taxonomie des catégories —
            # avant ce correctif, n'importe quel Lecteur authentifié
            # pouvait créer des catégories arbitraires (juste IsAuthenticated).
            return [permissions.IsAuthenticated(), IsAdminOrPublisher()]
        return [permissions.AllowAny()]


class CategoryDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Modification/suppression d'une catégorie — réservée aux administrateurs."""
    queryset = Category.objects.all()
    serializer_class = CategorySerializer

    def get_permissions(self):
        if self.request.method in ('GET', 'HEAD', 'OPTIONS'):
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated(), IsAdmin()]


class PublicationListView(generics.ListAPIView):
    serializer_class = PublicationSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        qs = Publication.objects.filter(status='published').select_related('publisher', 'category')
        search = self.request.query_params.get('search')
        category = self.request.query_params.get('category')
        pub_type = self.request.query_params.get('type')
        is_free = self.request.query_params.get('is_free')
        publisher_id = self.request.query_params.get('publisher_id')
        if search:
            qs = qs.filter(Q(title__icontains=search) | Q(description__icontains=search) | Q(tags__icontains=search))
        if category:
            normalized = category.strip()
            cat_slug = slugify(normalized)
            stem = normalized.rstrip('s')
            stem_slug = cat_slug.rstrip('s')
            qs = qs.filter(
                Q(category__slug__iexact=normalized) |
                Q(category__name__iexact=normalized) |
                Q(category__slug__iexact=cat_slug) |
                Q(category__name__icontains=stem) |
                Q(category__slug__icontains=stem_slug)
            )
        if pub_type:
            qs = qs.filter(pub_type=pub_type)
        if is_free is not None:
            qs = qs.filter(is_free=(is_free.lower() == 'true'))
        if publisher_id:
            qs = qs.filter(publisher_id=publisher_id)
        # Avantage réel du plan plateforme : une publication mise en avant
        # (is_featured, limité selon le plan — voir PlatformPlan) apparaît
        # toujours avant les autres, à recherche/filtre égal.
        return qs.order_by('-is_featured', '-created_at')


class PublicationDetailView(generics.RetrieveAPIView):
    serializer_class = PublicationSerializer
    permission_classes = [permissions.AllowAny]
    queryset = Publication.objects.all()

    def retrieve(self, request, *args, **kwargs):
        obj = self.get_object()
        if self._register_view_once(request, obj):
            obj.views_count += 1
            obj.save(update_fields=['views_count'])
            # Trace la vue (dédupliquée) pour le calcul des tendances
            # « À la une » (vues des dernières 48h).
            try:
                from .models import PublicationView
                if request.user and request.user.is_authenticated:
                    viewer_key = f'user_{request.user.id}'
                else:
                    viewer_key = f'ip_{request.META.get("REMOTE_ADDR", "unknown")}'
                PublicationView.objects.create(
                    publication=obj, viewer_key=viewer_key
                )
            except Exception:
                logger.exception("Echec enregistrement PublicationView pour %s", obj.id)
            self._broadcast_view_count(obj)
        return super().retrieve(request, *args, **kwargs)

    def _register_view_once(self, request, obj):
        """Anti-spam sur le compteur de vues : sans ça, rafraîchir la même
        page en boucle (ou un script) gonfle artificiellement views_count à
        l'infini — une métrique censée refléter un vrai lectorat perdrait
        tout son sens (statistiques éditeur faussées, mise en avant
        "priority_listing" trichée). On identifie le visiteur (utilisateur
        connecté, sinon IP) et on ne compte qu'UNE SEULE vue par visiteur
        et par publication toutes les 30 minutes."""
        from django.core.cache import cache

        if request.user and request.user.is_authenticated:
            visitor_key = f'user_{request.user.id}'
        else:
            visitor_key = f'ip_{request.META.get("REMOTE_ADDR", "unknown")}'

        cache_key = f'pubview:{obj.id}:{visitor_key}'
        if cache.get(cache_key):
            return False
        cache.set(cache_key, True, timeout=60 * 30)  # 30 minutes
        return True

    def _broadcast_view_count(self, obj):
        # Diffuse la mise à jour du compteur de vues en direct sur le même
        # salon WebSocket que la conversation de cet article (réutilise la
        # connexion déjà ouverte par quiconque a l'article affiché — pas de
        # canal supplémentaire à gérer côté client).
        try:
            from asgiref.sync import async_to_sync
            from channels.layers import get_channel_layer

            channel_layer = get_channel_layer()
            if channel_layer is None:
                return
            async_to_sync(channel_layer.group_send)(
                f'conversation_{obj.id}',
                {
                    'type': 'new_message',
                    'payload': {'event': 'views_updated', 'views_count': obj.views_count},
                },
            )
        except Exception:
            logger.exception("Echec diffusion WebSocket du compteur de vues pour %s", obj.id)

        # Prévient aussi l'éditeur lui-même (ses statistiques changent à
        # chaque vue) via son canal personnel — indépendant du salon de
        # l'article, pour que son tableau de bord se mette à jour même
        # s'il n'a pas l'article ouvert.
        from apps.notifications.realtime import push_to_user
        push_to_user(obj.publisher_id, 'stats_changed', {'reason': 'new_view'})


def _check_priority_slot(user, current_instance):
    """Vérifie que l'éditeur ne dépasse pas son quota de mise en avant
    (max_priority_slots de son plan plateforme actif) — le seul avantage
    réellement différencié entre plans (voir PlatformPlan). Utilisée à la
    fois à la création et à la modification d'une publication."""
    from rest_framework.exceptions import PermissionDenied

    active_sub = user.platform_subscriptions.filter(
        status='active'
    ).select_related('plan').first()
    max_slots = active_sub.plan.max_priority_slots if (active_sub and active_sub.plan) else 0

    if max_slots <= 0:
        raise PermissionDenied(
            "Votre plan actuel n'inclut pas la mise en avant de publications. "
            "Passez à un plan supérieur pour en bénéficier."
        )

    already_featured = Publication.objects.filter(
        publisher=user, is_featured=True
    ).exclude(pk=current_instance.pk if current_instance else None).count()

    if already_featured >= max_slots:
        raise PermissionDenied(
            f"Votre plan permet de mettre en avant {max_slots} publication(s) maximum "
            f"en même temps. Retirez-en une avant d'en ajouter une nouvelle."
        )


class PublisherPublicationsView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated, IsPublisher]

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return PublicationCreateSerializer
        return PublicationSerializer

    def get_queryset(self):
        return Publication.objects.filter(publisher=self.request.user).select_related('category')

    def perform_create(self, serializer):
        # PublisherProfile.is_active est la source de vérité unique pour
        # « cet éditeur a-t-il accès à la plateforme » : soit parce qu'il
        # n'a pas (ou plus) d'abonnement plateforme actif, soit parce qu'un
        # administrateur l'a suspendu. Dans les deux cas, il garde accès à
        # son tableau de bord (avertissements, historique) mais ne peut pas
        # publier de nouveau contenu.
        profile = getattr(self.request.user, 'publisher_profile', None)
        if profile and not profile.is_active:
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied(
                "Vous n'avez pas accès à la publication : votre compte a été suspendu "
                "par un administrateur. Aucun paiement n'est requis sur la plateforme — "
                "contactez le support pour plus d'informations."
            )

        # ─── AVANTAGE RÉEL DES PLANS : MISE EN AVANT UNIQUEMENT ────────────
        # Sur demande explicite : aucune limite de nombre de publications
        # ni de restriction sur le type de contenu (vidéo comprise) —
        # ce sont des fonctionnalités déjà existantes de la plateforme,
        # accessibles à tout éditeur quel que soit son plan (Basique
        # inclus). Seule la mise en avant (is_featured) est réellement
        # limitée selon le plan, y compris si cochée dès la création.
        if serializer.validated_data.get('is_featured') is True:
            _check_priority_slot(self.request.user, None)
        serializer.save()
        # (la vérification de palier éditeur se fait désormais via signal
        # Django sur Publication, voir apps.publications.signals — couvre
        # aussi les publications qui passent en 'published' après coup,
        # pas seulement à la création)


class PublicationUpdateView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAuthenticated, IsOwnerOrAdmin]

    def get_serializer_class(self):
        return PublicationCreateSerializer

    def perform_update(self, serializer):
        # Si l'éditeur active la mise en avant sur cette publication,
        # vérifier qu'il ne dépasse pas le quota de son plan — le seul
        # avantage réellement différencié entre plans (voir plus haut).
        if serializer.validated_data.get('is_featured') is True:
            _check_priority_slot(self.request.user, serializer.instance)
        serializer.save()

    def get_queryset(self):
        if self.request.user.role == 'admin':
            return Publication.objects.all()
        return Publication.objects.filter(publisher=self.request.user)


class PublicationResetStatsView(APIView):
    """POST /api/publications/my/<pk>/reset-stats/

    Remet à zéro les compteurs d'une publication de l'éditeur connecté
    (vues, téléchargements, et historique des vues tracées) — l'éditeur
    repart d'une page blanche pour ses statistiques.
    """
    permission_classes = [permissions.IsAuthenticated, IsPublisher]

    def post(self, request, pk):
        pub = Publication.objects.filter(pk=pk, publisher=request.user).first()
        if not pub:
            return Response({'error': 'Publication introuvable ou pas la vôtre.'}, status=404)
        pub.views_count = 0
        pub.downloads_count = 0
        pub.save(update_fields=['views_count', 'downloads_count'])
        from .models import PublicationView
        PublicationView.objects.filter(publication=pub).delete()
        return Response({'detail': 'Statistiques remises à zéro.', 'views_count': 0, 'downloads_count': 0})


class AdminPublicationsView(generics.ListAPIView):
    serializer_class = PublicationSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def get_queryset(self):
        qs = Publication.objects.all().select_related('publisher', 'category')
        status_filter = self.request.query_params.get('status')
        if status_filter:
            qs = qs.filter(status=status_filter)
        return qs


class ReviewCreateView(generics.CreateAPIView):
    """Un utilisateur ne peut laisser qu'un seul commentaire/avis par article
    (contrainte `unique_together` sur le modèle Review). Poster un nouveau
    commentaire sur un article où l'utilisateur a déjà commenté MET À JOUR
    son commentaire existant plutôt que d'échouer avec une erreur
    d'intégrité — cela permet de "modifier son message" dans la
    conversation, comme on le ferait en éditant son dernier message.
    """
    serializer_class = ReviewSerializer
    permission_classes = [permissions.IsAuthenticated]

    def create(self, request, *args, **kwargs):
        pub = Publication.objects.get(pk=self.kwargs['pk'])
        existing = Review.objects.filter(publication=pub, reader=request.user).first()
        if existing:
            serializer = self.get_serializer(existing, data=request.data, partial=True)
            serializer.is_valid(raise_exception=True)
            serializer.save()
            return Response(serializer.data, status=status.HTTP_200_OK)
        return super().create(request, *args, **kwargs)

    def perform_create(self, serializer):
        pub = Publication.objects.get(pk=self.kwargs['pk'])
        serializer.save(reader=self.request.user, publication=pub)
        # Notifier l'éditeur d'un nouvel avis
        if pub.publisher and pub.publisher != self.request.user:
            try:
                from apps.notifications.views import send_notification
                author_name = self.request.user.name or self.request.user.username
                send_notification(
                    user=pub.publisher,
                    type_notif='new_comment',
                    title=f'Nouvel avis sur « {pub.title[:40]} »',
                    message=f'{author_name} a laissé un avis sur votre article.',
                    data={'article_id': str(pub.id)},
                )
            except Exception:
                pass


class ReviewListView(generics.ListAPIView):
    serializer_class = ReviewSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        return Review.objects.filter(publication_id=self.kwargs['pk']).select_related('reader').order_by('-created_at', '-id')


class AdminReviewListView(generics.ListAPIView):
    """Modération : liste de tous les avis de la plateforme (admin seulement)."""
    serializer_class = ReviewSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def get_queryset(self):
        qs = Review.objects.select_related('reader', 'publication').all().order_by('-created_at', '-id')
        rating = self.request.query_params.get('rating')
        if rating:
            qs = qs.filter(rating=rating)
        return qs


class AdminReviewDeleteView(generics.DestroyAPIView):
    """Suppression d'un avis inapproprié (admin seulement)."""
    queryset = Review.objects.all()
    permission_classes = [permissions.IsAuthenticated, IsAdmin]


class ConversationFeedView(APIView):
    """GET /api/publications/<pk>/conversation-feed/

    Renvoie la conversation complète d'un article, façon fil de commentaires
    Facebook : le premier message de chaque utilisateur est son avis noté
    par étoiles (`Review`), puis viennent tous les échanges libres
    (`Comment`), avec réponses (`parent_id`). Le tout est trié
    chronologiquement pour former un seul fil de discussion.
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request, pk):
        pub = get_object_or_404(Publication, pk=pk)
        current_user = request.user if request.user.is_authenticated else None

        items = []
        for r in Review.objects.filter(publication=pub).select_related('reader'):
            items.append({
                'id': f'review-{r.id}',
                'type': 'review',
                'author_id': str(r.reader_id),
                'author_name': r.reader.name or r.reader.username,
                'author_badge': r.reader.badge_label,
                'text': r.comment or '',
                'rating': r.rating,
                'parent_id': None,
                'created_at': r.created_at,
                'updated_at': r.updated_at,
                'is_mine': bool(current_user and r.reader_id == current_user.id),
            })
        for c in Comment.objects.filter(publication=pub).select_related('author'):
            items.append({
                'id': f'comment-{c.id}',
                'type': 'comment',
                'author_id': str(c.author_id),
                'author_name': c.author.name or c.author.username,
                'author_badge': c.author.badge_label,
                'text': c.text,
                'rating': None,
                'parent_id': f'comment-{c.parent_id}' if c.parent_id else None,
                'created_at': c.created_at,
                'updated_at': c.updated_at,
                'is_mine': bool(current_user and c.author_id == current_user.id),
            })

        items.sort(key=lambda item: item['created_at'])
        serializer = ConversationMessageSerializer(items, many=True)
        return Response(serializer.data)


class CommentCreateView(generics.CreateAPIView):
    """POST /api/publications/<pk>/comments/add/

    Poste une réponse libre (façon Facebook) dans la conversation d'un
    article. `parent` (optionnel) permet de répondre à un commentaire
    précis ; sans `parent`, le message est un nouveau message de premier
    niveau dans le fil de discussion.
    """
    serializer_class = CommentSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        pub = get_object_or_404(Publication, pk=self.kwargs['pk'])
        parent_id = self.request.data.get('parent')
        parent = None
        if parent_id:
            parent = Comment.objects.filter(pk=parent_id, publication=pub).first()
        comment = serializer.save(author=self.request.user, publication=pub, parent=parent)

        author_name = self.request.user.name or self.request.user.username
        article_data = {'article_id': str(pub.id)}

        # Notifier l'éditeur d'un nouveau commentaire
        if pub.publisher and pub.publisher != self.request.user:
            try:
                from apps.notifications.views import send_notification
                send_notification(
                    user=pub.publisher,
                    type_notif='new_comment',
                    title=f'Nouveau commentaire sur « {pub.title[:40]} »',
                    message=f'{author_name} a commenté votre article.',
                    data=article_data,
                )
            except Exception:
                pass

        # Notifier l'auteur du commentaire parent si c'est une réponse
        if parent and parent.author != self.request.user and parent.author != pub.publisher:
            try:
                from apps.notifications.views import send_notification
                send_notification(
                    user=parent.author,
                    type_notif='new_reply',
                    title='Nouvelle réponse à votre commentaire',
                    message=f'{author_name} a répondu à votre message.',
                    data=article_data,
                )
            except Exception:
                pass


class CommentDeleteView(generics.DestroyAPIView):
    """DELETE /api/publications/comments/<pk>/ — l'auteur du message ou un
    administrateur peut le supprimer (modération)."""
    queryset = Comment.objects.all()
    serializer_class = CommentSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'admin':
            return Comment.objects.all()
        return Comment.objects.filter(author=user)


class PublicationFileAccessView(APIView):
    """Point d'accès unique et protégé au fichier d'une publication.

    L'URL brute du fichier n'est plus exposée telle quelle dans la réponse
    JSON générale : l'accès réel est vérifié côté serveur (abonnement actif,
    achat, gratuité ou propriété) avant de renvoyer le lien de téléchargement.
    Ceci empêche un lecteur non autorisé de contourner la limite de pages
    imposée côté client en interceptant simplement l'URL du PDF.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk):
        try:
            pub = Publication.objects.select_related('publisher').get(pk=pk, status='published')
        except Publication.DoesNotExist:
            return Response({'detail': 'Publication introuvable.'}, status=status.HTTP_404_NOT_FOUND)

        if not self._has_full_access(request.user, pub):
            return Response(
                {'detail': "Abonnement ou achat requis pour accéder au fichier complet."},
                status=status.HTTP_403_FORBIDDEN,
            )

        pub.downloads_count += 1
        pub.save(update_fields=['downloads_count'])
        return Response({'file_url': pub.file_url})

    @staticmethod
    def _has_full_access(user, pub):
        # Déléguée à Publication.is_accessible_by (source unique de vérité,
        # voir models.py) — anciennement dupliquée ici ET dans
        # PublicationSerializer, désormais fusionnées en une seule règle.
        return pub.is_accessible_by(user)


class ConversationListView(APIView):
    """GET /api/publications/conversations/

    Retourne, pour l'utilisateur connecté (Admin, Éditeur ou Lecteur — la
    page est strictement identique pour tous les rôles), la liste des
    articles où il a participé à la conversation (avis noté par étoiles
    et/ou réponses libres), triée du plus récent au plus ancien message,
    façon liste de discussions WhatsApp.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user

        hidden_ids = HiddenConversation.objects.filter(user=user).values_list(
            'publication_id', flat=True
        )
        # Un utilisateur "participe" à la conversation d'un article dès
        # qu'il y a laissé un avis (étoiles) OU un commentaire (réponse).
        review_pub_ids = Review.objects.filter(reader=user).values_list('publication_id', flat=True)
        comment_pub_ids = Comment.objects.filter(author=user).values_list('publication_id', flat=True)
        publication_ids = set(review_pub_ids) | set(comment_pub_ids)
        publication_ids -= set(hidden_ids)

        search = request.query_params.get('search')
        publications = Publication.objects.filter(id__in=publication_ids)
        if search:
            publications = publications.filter(title__icontains=search)

        read_map = {
            r.publication_id: r.last_read_at
            for r in ConversationRead.objects.filter(user=user, publication_id__in=publication_ids)
        }

        data = []
        for pub in publications:
            reviews = list(Review.objects.filter(publication=pub).select_related('reader'))
            comments = list(Comment.objects.filter(publication=pub).select_related('author'))
            total = len(reviews) + len(comments)
            if total == 0:
                continue

            # Dernier message, tous types confondus (avis ou commentaire).
            last_entry = max(
                [(r.updated_at, r.comment or '', r.reader.name or r.reader.username) for r in reviews]
                + [(c.updated_at, c.text, c.author.name or c.author.username) for c in comments],
                key=lambda t: t[0],
            )
            last_date, last_text, last_author = last_entry

            last_read_at = read_map.get(pub.id)
            all_dates = [r.updated_at for r in reviews] + [c.updated_at for c in comments]
            if last_read_at is None:
                new_count = total
            else:
                new_count = sum(1 for d in all_dates if d > last_read_at)

            data.append({
                'id_article': pub.id,
                'titre_article': pub.title,
                'date_dernier_commentaire': last_date,
                'nombre_total_commentaires': total,
                'texte_dernier_commentaire': last_text,
                'auteur_dernier_commentaire': last_author,
                'cover_image': pub.cover_image or '',
                'has_new_comments': new_count > 0,
                'nouveaux_commentaires_count': new_count,
            })

        data.sort(key=lambda item: item['date_dernier_commentaire'], reverse=True)
        serializer = ConversationSerializer(data, many=True)
        return Response(serializer.data)


class ConversationMarkReadView(APIView):
    """POST /api/publications/conversations/<pk>/read/

    Marque la conversation (les commentaires de l'article <pk>) comme lue
    par l'utilisateur connecté : met à jour `last_read_at` à maintenant,
    ce qui fait disparaître le badge "nouveaux commentaires".
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        pub = get_object_or_404(Publication, pk=pk)
        obj, _created = ConversationRead.objects.get_or_create(user=request.user, publication=pub)
        obj.save()  # force la mise à jour de auto_now même si l'objet existait déjà
        return Response({'detail': 'Conversation marquée comme lue.', 'last_read_at': obj.last_read_at})


class ConversationHideView(APIView):
    """POST /api/publications/conversations/<pk>/hide/

    "Quitte" la conversation : masque l'article de la page "Mes
    Conversations" de l'utilisateur, sans supprimer ses commentaires.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        pub = get_object_or_404(Publication, pk=pk)
        HiddenConversation.objects.get_or_create(user=request.user, publication=pub)
        return Response({'detail': 'Conversation retirée de votre liste.'}, status=status.HTTP_200_OK)

    def delete(self, request, pk):
        return self.post(request, pk)


# ─────────────────────────────────────────────────────────────────────────────
# Favoris du Lecteur & catégories personnelles ("playlists" façon YouTube)
# ─────────────────────────────────────────────────────────────────────────────

class ReaderCategoryListCreateView(generics.ListCreateAPIView):
    """GET/POST /api/publications/reader-categories/

    Catégories personnelles du Lecteur pour organiser ses favoris. N'a
    aucun rapport avec le modèle `Category` global (Admin/Éditeur) : chaque
    Lecteur ne voit et ne gère que ses propres catégories.
    """
    serializer_class = ReaderCategorySerializer
    permission_classes = [permissions.IsAuthenticated, IsReader]

    def get_queryset(self):
        return ReaderCategory.objects.filter(reader=self.request.user)

    def perform_create(self, serializer):
        serializer.save(reader=self.request.user)


class ReaderCategoryDeleteView(generics.DestroyAPIView):
    """DELETE /api/publications/reader-categories/<pk>/

    Supprime une catégorie personnelle. Les articles qui y étaient rangés
    restent dans les favoris du Lecteur (ils perdent juste ce rangement).
    """
    serializer_class = ReaderCategorySerializer
    permission_classes = [permissions.IsAuthenticated, IsReader]

    def get_queryset(self):
        return ReaderCategory.objects.filter(reader=self.request.user)


class FavoriteListView(APIView):
    """GET /api/publications/favorites/?category=<id>

    Liste les articles favoris du Lecteur connecté, avec les catégories
    personnelles dans lesquelles chacun est rangé. Filtrable par catégorie
    personnelle pour afficher le contenu d'une "playlist" précise.
    """
    permission_classes = [permissions.IsAuthenticated, IsReader]

    def get(self, request):
        qs = Favorite.objects.filter(reader=request.user).select_related('publication').prefetch_related('categories')
        category_id = request.query_params.get('category')
        if category_id:
            qs = qs.filter(categories__id=category_id)

        data = []
        for fav in qs:
            pub = fav.publication
            data.append({
                'id': pub.id,
                'title': pub.title,
                'description': pub.description,
                'cover_image': pub.cover_image or '',
                'category_ids': list(fav.categories.values_list('id', flat=True)),
                'added_at': fav.created_at,
            })
        serializer = FavoritePublicationSerializer(data, many=True)
        return Response(serializer.data)


class FavoriteAddOrUpdateView(APIView):
    """POST /api/publications/favorites/

    Ajoute un article aux favoris du Lecteur, en le rangeant optionnellement
    dans une ou plusieurs de ses catégories personnelles (playlists).
    Body : {"publication": <id>, "category_ids": [<id>, ...]}
    Rappeler cet endpoint sur un article déjà favori met simplement à jour
    ses catégories (permet de "re-ranger" un favori existant).
    """
    permission_classes = [permissions.IsAuthenticated, IsReader]

    def post(self, request):
        pub_id = request.data.get('publication')
        if not pub_id:
            return Response({'detail': "Le champ 'publication' est requis."}, status=status.HTTP_400_BAD_REQUEST)
        pub = get_object_or_404(Publication, pk=pub_id)

        favorite, _created = Favorite.objects.get_or_create(reader=request.user, publication=pub)

        category_ids = request.data.get('category_ids')
        if category_ids is not None:
            categories = ReaderCategory.objects.filter(reader=request.user, id__in=category_ids)
            favorite.categories.set(categories)

        return Response({'detail': 'Article ajouté aux favoris.', 'publication': pub.id}, status=status.HTTP_200_OK)


class FavoriteRemoveView(APIView):
    """DELETE /api/publications/favorites/<publication_id>/

    Retire un article des favoris du Lecteur (et de toutes ses playlists)."""
    permission_classes = [permissions.IsAuthenticated, IsReader]

    def delete(self, request, publication_id):
        Favorite.objects.filter(reader=request.user, publication_id=publication_id).delete()
        return Response({'detail': 'Retiré des favoris.'}, status=status.HTTP_200_OK)


class MediaUploadView(APIView):
    """POST /api/publications/upload-media/

    Permet d'uploader un fichier média (image, PDF, vidéo) et de retourner
    son URL absolue sur le serveur.
    """
    permission_classes = [permissions.IsAuthenticated]

    # ─── SÉCURITÉ ─────────────────────────────────────────────────────────
    # Avant ce garde-fou, n'importe quel utilisateur connecté (même un
    # simple lecteur) pouvait uploader un fichier de N'IMPORTE QUEL TYPE
    # (exécutable, script, HTML avec JS embarqué → XSS stocké une fois servi
    # depuis /media/) et de N'IMPORTE QUELLE TAILLE (déni de service par
    # remplissage disque). On restreint aux extensions réellement utilisées
    # par la plateforme et on plafonne la taille.
    ALLOWED_EXTENSIONS = {
        '.jpg', '.jpeg', '.png', '.gif', '.webp',
        '.pdf', '.mp4', '.mov', '.webm',
    }
    MAX_UPLOAD_SIZE = 50 * 1024 * 1024  # 50 Mo

    def post(self, request, *args, **kwargs):
        import os
        file_obj = request.FILES.get('file')
        if not file_obj:
            return Response({'error': 'Aucun fichier fourni.'}, status=status.HTTP_400_BAD_REQUEST)

        ext = os.path.splitext(file_obj.name)[1].lower()
        if ext not in self.ALLOWED_EXTENSIONS:
            return Response(
                {'error': f"Type de fichier non autorisé ({ext or 'inconnu'})."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if file_obj.size > self.MAX_UPLOAD_SIZE:
            return Response(
                {'error': 'Fichier trop volumineux (50 Mo maximum).'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Enregistrer dans media/publications/uploads/
        from django.core.files.storage import default_storage
        from django.conf import settings

        file_name = default_storage.save(f"publications/uploads/{file_obj.name}", file_obj)
        file_url = default_storage.url(file_name)

        if request is not None:
            url = request.build_absolute_uri(file_url)
        else:
            backend_url = getattr(settings, 'BACKEND_URL', 'http://localhost:8000')
            url = f"{backend_url.rstrip('/')}{file_url}"

        return Response({'url': url}, status=status.HTTP_201_CREATED)


# ─────────────────────────────────────────────────────────────────────────────
# « À LA UNE » : mise en avant payante (façon publicité Facebook) + tendances
# (publications à fort nombre de vues sur une courte période)
# ─────────────────────────────────────────────────────────────────────────────

# Tarifs de mise en avant payante (FCFA) par durée — la plateforme perçoit
# 100 % de ce montant (c'est une publicité, pas une vente de contenu).
FEATURED_PRICES = {
    7: 5000,
    14: 8000,
    30: 12000,
}


class FeaturedPublicationsView(APIView):
    """GET /api/publications/featured/

    Vitrine « À la une » de l'accueil, deux sources combinées :
    - `featured` : publications mises en avant (payantes/plan ou manuelles),
      triées de la plus récente à la plus ancienne.
    - `trending` : publications à fort nombre de vues sur les 48 dernières
      heures (nombre impressionnant de vues en peu de temps), triées par
      popularité décroissante.
    """
    permission_classes = [permissions.AllowAny]
    serializer_class = PublicationSerializer

    # Jusqu'à 12 publications « À la une » (demande explicite) — la vitrine
    # reste un carrousel horizontal, le nombre d'éléments n'a pas d'impact
    # sur la disposition.
    FEATURED_LIMIT = 12
    TRENDING_LIMIT = 12
    TRENDING_WINDOW_HOURS = 48

    def get(self, request):
        from django.utils import timezone
        from datetime import timedelta
        from django.db.models import Count

        published = Publication.objects.filter(status='published').select_related('publisher', 'category')

        # 1) Mises en avant explicites (payantes ou manuelles)
        featured_qs = published.filter(is_featured=True).order_by('-created_at')[:self.FEATURED_LIMIT]

        # 2) Tendances : le plus de vues (dédupliquées) sur les 48 dernières
        # heures, avec un plancher pour éviter d'afficher des publications
        # quasi sans vues.
        cutoff = timezone.now() - timedelta(hours=self.TRENDING_WINDOW_HOURS)
        from .models import PublicationView
        trending_ids = (
            PublicationView.objects
            .filter(viewed_at__gte=cutoff)
            .values('publication_id')
            .annotate(vues=Count('id'))
            .filter(vues__gte=3)
            .order_by('-vues')
            .values_list('publication_id', flat=True)[:self.TRENDING_LIMIT]
        )
        # Conserver l'ordre de popularité (order_by de la liste d'ids)
        trending_list = []
        trending_pubs = {
            p.id: p
            for p in published.filter(id__in=list(trending_ids))
        }
        for pid in trending_ids:
            if pid in trending_pubs:
                trending_list.append(trending_pubs[pid])

        serializer = self.serializer_class(featured_qs, many=True, context={'request': request})
        trending_serializer = self.serializer_class(
            trending_list, many=True, context={'request': request}
        )
        return Response({
            'featured': serializer.data,
            'trending': trending_serializer.data,
        })


def _activer_featured_promotion(promotion, transaction=None):
    """Active une promotion « À la une » : marque la publication mise en
    avant et planifie l'expiration."""
    from django.utils import timezone
    from datetime import timedelta

    now = timezone.now()
    promotion.status = 'active'
    promotion.starts_at = now
    promotion.ends_at = now + timedelta(days=promotion.duration_days)
    promotion.transaction = transaction
    promotion.save(update_fields=['status', 'starts_at', 'ends_at', 'transaction'])

    pub = promotion.publication
    pub.is_featured = True
    pub.save(update_fields=['is_featured'])

    # Notifie l'éditeur
    try:
        from apps.notifications.views import send_notification
        send_notification(
            user=promotion.publisher,
            type_notif='featured_activated',
            title='Votre publication est à la une 🎉',
            message=(
                f'« {pub.title[:40]} » est mise en avant sur l\'accueil '
                f'pendant {promotion.duration_days} jours.'
            ),
            data={'publication_id': str(pub.id)},
        )
    except Exception:
        logger.exception("Echec notification mise en avant %s", promotion.id)


def _initier_transaction_featured(user, promotion, montant, mode_paiement, phone=''):
    """Crée la transaction de mise en avant (status pending) et, en mode
    portefeuille, la valide immédiatement. Retourne (transaction, payload)."""
    from apps.paiements.models import Transaction
    import uuid
    from decimal import Decimal
    from django.utils import timezone

    montant = Decimal(str(montant))
    reference = str(uuid.uuid4())

    if mode_paiement == 'wallet':
        from apps.accounts.models import PublisherProfile
        from django.db import transaction as db_transaction

        with db_transaction.atomic():
            profile = PublisherProfile.objects.select_for_update().get(user=user)
            if profile.solde < montant:
                return None, {'error': 'Solde éditeur insuffisant pour cette mise en avant.'}
            profile.solde -= montant
            profile.save(update_fields=['solde'])

            tx = Transaction.objects.create(
                reference=reference,
                payer=user,
                beneficiaire=None,
                publication=promotion.publication,
                type_transaction='featured',
                montant_brut=montant,
                commission=montant,
                montant_net=0,
                status='success',
                processed_at=timezone.now(),
                description=f'Mise en avant « {promotion.publication.title[:40]} » ({promotion.duration_days}j)',
                metadata={'mode_paiement': 'wallet', 'featured_promotion_id': promotion.id},
            )
            _activer_featured_promotion(promotion, transaction=tx)
            try:
                from apps.comptabilite.utils import enregistrer_ecriture
                enregistrer_ecriture(tx)
            except Exception:
                logger.exception("Ecriture comptable mise en avant %s", tx.id)
        return tx, {'transaction': str(tx.reference), 'status': tx.status, 'message': 'Mise en avant activée avec succès.'}

    # Mobile money / carte via CinetPay — la MÊME passerelle que les
    # lecteurs (système de paiement unifié : fin de l'ancien flux Movapay
    # réservé aux éditeurs/admins). En l'absence de clés CinetPay dans le
    # .env, le service bascule automatiquement en mode simulation.
    from apps.paiements.cinetpay import cinetpay_service
    channels = {
        'wave': 'MOBILE',
        'orange_money': 'MOBILE',
        'moov_money': 'MOBILE',
        'card': 'CARD',
    }.get(mode_paiement, 'ALL')
    result = cinetpay_service.initier_paiement(
        montant=float(montant),
        phone=phone,
        reference=reference,
        description=f'Digital Press — Mise en avant {promotion.duration_days}j',
        channels=channels,
    )
    tx = Transaction.objects.create(
        reference=reference,
        payer=user,
        beneficiaire=None,
        publication=promotion.publication,
        type_transaction='featured',
        montant_brut=montant,
        commission=montant,
        montant_net=0,
        phone_payer=phone,
        status='pending',
        description=f'Mise en avant « {promotion.publication.title[:40]} » ({promotion.duration_days}j)',
        metadata={**result, 'featured_promotion_id': promotion.id},
    )
    promotion.transaction = tx
    promotion.save(update_fields=['transaction'])
    return tx, {
        'transaction': str(tx.reference),
        'payment_url': result.get('payment_url', ''),
        'cinetpay_ref': result.get('cinetpay_ref', ''),
        'message': result.get('message', ''),
    }


class FeaturePublicationView(APIView):
    """POST /api/publications/<pk>/feature/

    L'éditeur met sa publication « À la une » en payant (façon publicité
    Facebook). Body : {"days": 7|14|30, "mode_paiement": "wallet"|"simulation"|"movapay", "phone": "..."}
    - `wallet` : payé immédiatement depuis le solde d'éditeur, activé tout de suite.
    - `simulation` / `movapay` : paiement mobile money initié, à vérifier via
      /feature/verify/ (ou le webhook).
    """
    permission_classes = [permissions.IsAuthenticated, IsPublisher]

    def post(self, request, pk):
        from rest_framework.exceptions import PermissionDenied
        from django.utils import timezone

        try:
            pub = Publication.objects.get(pk=pk, publisher=request.user)
        except Publication.DoesNotExist:
            return Response({'error': 'Publication introuvable ou pas la vôtre.'}, status=404)

        if pub.status != 'published':
            return Response({'error': 'Seule une publication publiée peut être mise à la une.'}, status=400)

        # Pas de double mise en avant tant qu'une promotion est active.
        active = pub.featured_promotions.filter(status='active').exists()
        if active:
            return Response({'error': 'Cette publication est déjà à la une.'}, status=400)

        days = request.data.get('days')
        try:
            days = int(days)
        except (TypeError, ValueError):
            return Response({'error': 'Durée invalide (7, 14 ou 30 jours).'}, status=400)
        if days not in FEATURED_PRICES:
            return Response({'error': 'Durée invalide (7, 14 ou 30 jours).'}, status=400)

        montant = FEATURED_PRICES[days]
        mode = request.data.get('mode_paiement', 'simulation')
        phone = request.data.get('phone', '')

        promotion = self._get_or_create_promotion(pub, days, montant)

        if promotion.status == 'active':
            return Response({'error': 'Cette publication est déjà à la une.'}, status=400)

        tx, payload = _initier_transaction_featured(
            request.user, promotion, montant, mode, phone
        )
        if payload.get('error'):
            return Response({'error': payload['error']}, status=400)
        return Response(payload, status=status.HTTP_201_CREATED)

    def _get_or_create_promotion(self, pub, days, montant):
        from .models import FeaturedPromotion
        existing = (
            pub.featured_promotions
            .filter(status__in=['pending', 'active'])
            .order_by('-created_at')
            .first()
        )
        if existing:
            existing.duration_days = days
            existing.montant = montant
            existing.save(update_fields=['duration_days', 'montant'])
            return existing
        return FeaturedPromotion.objects.create(
            publication=pub,
            publisher=pub.publisher,
            duration_days=days,
            montant=montant,
        )


class VerifyFeaturePaymentView(APIView):
    """POST /api/publications/<pk>/feature/verify/  Body: {"reference": "..."}

    Vérifie le paiement mobile money d'une mise en avant et active la
    promotion si le paiement est confirmé."""
    permission_classes = [permissions.IsAuthenticated, IsPublisher]

    def post(self, request, pk):
        from apps.paiements.models import Transaction
        from apps.paiements.movapay import movapay_service
        from .models import FeaturedPromotion
        from django.db import transaction as db_transaction
        from django.utils import timezone

        reference = request.data.get('reference', '')
        if not reference:
            return Response({'error': 'Référence manquante.'}, status=400)

        promotion = (
            FeaturedPromotion.objects
            .filter(publication_id=pk, publisher=request.user)
            .select_related('publication')
            .order_by('-created_at')
            .first()
        )
        if not promotion:
            return Response({'error': 'Aucune mise en avant en attente.'}, status=404)

        tx = promotion.transaction
        if tx is None or str(tx.reference) != str(reference):
            return Response({'error': 'Transaction inconnue pour cette mise en avant.'}, status=404)

        if tx.status in ('success', 'failed', 'cancelled', 'refunded'):
            if tx.status == 'success' and promotion.status == 'pending':
                _activer_featured_promotion(promotion, transaction=tx)
            return Response({
                'status': tx.status,
                'featured': promotion.status == 'active',
                'message': 'Paiement déjà traité.',
            })

        from apps.paiements.cinetpay import cinetpay_service
        result = cinetpay_service.verifier_paiement(
            reference=str(tx.reference)
        )

        if result.get('status') == 'success':
            with db_transaction.atomic():
                tx = Transaction.objects.select_for_update().get(pk=tx.pk)
                if tx.status == 'pending':
                    tx.status = 'success'
                    tx.processed_at = timezone.now()
                    tx.save(update_fields=['status', 'processed_at'])
                    _activer_featured_promotion(promotion, transaction=tx)
                    try:
                        from apps.comptabilite.utils import enregistrer_ecriture
                        enregistrer_ecriture(tx)
                    except Exception:
                        logger.exception("Ecriture comptable mise en avant %s", tx.id)
        elif result.get('status') in ('failed', 'cancelled'):
            tx.status = result['status']
            tx.save(update_fields=['status'])

        return Response({
            'status': tx.status,
            'featured': promotion.status == 'active',
            'message': result.get('message', ''),
        })


class AdminFeaturedPromotionsView(APIView):
    """GET/POST /api/publications/admin/featured-promotions/

    Modération des mises en avant « À la une » par l'administrateur :
    - GET : liste complète (toutes promotions, triées de la plus récente),
      avec montant, statut, période et publication.
    - POST {"promotion_id": X, "action": "cancel"} : annule une promotion
      (active ou en attente) — retire la mise en avant de l'accueil et
      passe la promotion en 'cancelled'.
    """
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def get(self, request):
        from .models import FeaturedPromotion

        status_filter = request.query_params.get('status')
        qs = FeaturedPromotion.objects.select_related(
            'publication', 'publisher', 'transaction'
        ).order_by('-created_at')
        if status_filter:
            qs = qs.filter(status=status_filter)

        data = [
            {
                'id': p.id,
                'publication_id': p.publication_id,
                'publication_title': p.publication.title,
                'publisher_id': p.publisher_id,
                'publisher_name': p.publisher.name or p.publisher.username,
                'duration_days': p.duration_days,
                'montant': str(p.montant),
                'status': p.status,
                'starts_at': p.starts_at,
                'ends_at': p.ends_at,
                'created_at': p.created_at,
                'transaction_ref': p.transaction.reference if p.transaction else None,
            }
            for p in qs
        ]
        total_revenue = sum(
            float(p.montant) for p in qs if p.status == 'active'
        )
        return Response({
            'results': data,
            'total_active_revenue': total_revenue,
        })

    def post(self, request):
        from .models import FeaturedPromotion

        promo_id = request.data.get('promotion_id')
        action = request.data.get('action')
        if not promo_id or action != 'cancel':
            return Response({'error': 'promotion_id + action=cancel requis.'}, status=400)

        promo = FeaturedPromotion.objects.select_related('publication').filter(
            pk=promo_id
        ).first()
        if not promo:
            return Response({'error': 'Promotion introuvable.'}, status=404)

        if promo.status == 'active':
            pub = promo.publication
            # Ne retire la mise en avant que si aucune autre promotion active
            # ne couvre encore cette publication.
            still_active = pub.featured_promotions.filter(
                status='active'
            ).exclude(pk=promo.pk).exists()
            if not still_active:
                pub.is_featured = False
                pub.save(update_fields=['is_featured'])
        promo.status = 'cancelled'
        promo.save(update_fields=['status'])
        return Response({'detail': 'Promotion annulée.', 'id': promo.id})


class PublisherViewsHistoryView(APIView):
    """GET /api/publications/my/views-history/?days=14

    Historique des vues des publications de l'éditeur connecté, jour par
    jour (basé sur le modèle PublicationView, vues dédupliquées par
    visiteur/30 min). Sert au graphique « Historique des vues » de
    l'espace Éditeur.

    Réponse : {days, series: [{date, count}], per_publication: [{id, title,
    series: [...]}]} — `series` est rempli du plus ancien au plus récent,
    avec des 0 pour les jours sans vue.
    """
    permission_classes = [permissions.IsAuthenticated, IsPublisher]

    def get(self, request):
        from django.utils import timezone
        from datetime import timedelta
        from django.db.models import Count
        from django.db.models.functions import TruncDate
        from .models import PublicationView

        try:
            days = min(int(request.query_params.get('days', 14)), 60)
        except (TypeError, ValueError):
            days = 14
        days = max(days, 1)

        today = timezone.now().date()
        dates = [today - timedelta(days=i) for i in range(days - 1, -1, -1)]
        date_strs = [d.isoformat() for d in dates]

        pubs = Publication.objects.filter(publisher=request.user)
        start = timezone.make_aware(
            timezone.datetime.combine(dates[0], timezone.datetime.min.time())
        )

        rows = (
            PublicationView.objects
            .filter(publication__publisher=request.user, viewed_at__gte=start)
            .annotate(day=TruncDate('viewed_at'))
            .values('day', 'publication_id')
            .annotate(total=Count('id'))
            .order_by('day')
        )

        # Compteur global par date
        global_by_date = {}
        per_pub = {}
        for row in rows:
            day = row['day'].isoformat()
            pid = row['publication_id']
            global_by_date[day] = global_by_date.get(day, 0) + row['total']
            per_pub.setdefault(pid, {})[day] = row['total']

        series = [{'date': d, 'count': global_by_date.get(d, 0)} for d in date_strs]
        per_publication = [
            {
                'id': pub.id,
                'title': pub.title,
                'series': [
                    {'date': d, 'count': per_pub.get(pub.id, {}).get(d, 0)}
                    for d in date_strs
                ],
            }
            for pub in pubs.order_by('-created_at')
        ]

        return Response({
            'days': days,
            'series': series,
            'per_publication': per_publication,
        })


class PublisherStatsExportView(APIView):
    """GET : export CSV des statistiques détaillées de l'éditeur connecté
    (une ligne par publication : titre, type, vues, favoris, date).

    ─── AVANTAGE RÉEL DU PLAN : EXPORT STATISTIQUES ────────────────────
    Réservé aux plans dont has_stats_export=True (Standard/Premium par
    défaut) — un vrai avantage concret, pas juste un texte affiché.
    """
    permission_classes = [permissions.IsAuthenticated, IsPublisher]

    def get(self, request):
        active_sub = request.user.platform_subscriptions.filter(
            status='active'
        ).select_related('plan').first()
        can_export = bool(active_sub and active_sub.plan and active_sub.plan.has_stats_export)
        if not can_export:
            return Response(
                {'error': "L'export de statistiques n'est pas inclus dans votre plan actuel."},
                status=status.HTTP_403_FORBIDDEN,
            )

        import csv
        from django.http import HttpResponse

        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = 'attachment; filename="statistiques.csv"'
        writer = csv.writer(response)
        writer.writerow(['Titre', 'Type', 'Statut', 'Vues', 'Favoris', 'Créé le'])

        publications = Publication.objects.filter(publisher=request.user).annotate(
            fav_count=Count('favorited_by')
        )
        for pub in publications:
            writer.writerow([
                pub.title, pub.get_pub_type_display(), pub.get_status_display(),
                pub.views_count, pub.fav_count, pub.created_at.strftime('%Y-%m-%d'),
            ])

        return response
