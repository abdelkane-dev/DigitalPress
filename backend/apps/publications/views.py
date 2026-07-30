from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Q, Max, Count
from django.shortcuts import get_object_or_404
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
from apps.accounts.permissions import IsAdmin, IsPublisher, IsOwnerOrAdmin, IsReader


class CategoryListView(generics.ListCreateAPIView):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer

    def get_permissions(self):
        if self.request.method == 'POST':
            return [permissions.IsAuthenticated()]
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
        ordering = self.request.query_params.get('ordering', '-created_at')

        if search:
            # Point 6 : recherche multi-critères sur titre, description, tags, éditeur et catégorie
            qs = qs.filter(
                Q(title__icontains=search) |
                Q(description__icontains=search) |
                Q(tags__icontains=search) |
                Q(publisher__name__icontains=search) |
                Q(publisher__publisher_profile__company_name__icontains=search) |
                Q(category__name__icontains=search)
            ).distinct()
        if category:
            normalized = category.strip()
            qs = qs.filter(
                Q(category__slug__iexact=normalized) |
                Q(category__name__iexact=normalized)
            )
        if pub_type:
            qs = qs.filter(pub_type=pub_type)
        if is_free is not None:
            qs = qs.filter(is_free=(is_free.lower() == 'true'))
        if publisher_id:
            qs = qs.filter(publisher_id=publisher_id)

        # Tri sécurisé
        allowed_orderings = {
            'created_at', '-created_at', 'prix', '-prix',
            'views_count', '-views_count', 'average_rating', '-average_rating',
        }
        if ordering in allowed_orderings:
            qs = qs.order_by(ordering)
        else:
            qs = qs.order_by('-created_at')
        return qs



class PublicationDetailView(generics.RetrieveAPIView):
    serializer_class = PublicationSerializer
    permission_classes = [permissions.AllowAny]
    queryset = Publication.objects.all()

    def retrieve(self, request, *args, **kwargs):
        obj = self.get_object()
        obj.views_count += 1
        obj.save(update_fields=['views_count'])
        return super().retrieve(request, *args, **kwargs)


class PublisherPublicationsView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated, IsPublisher]

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return PublicationCreateSerializer
        return PublicationSerializer

    def get_queryset(self):
        return Publication.objects.filter(publisher=self.request.user).select_related('category')

    def perform_create(self, serializer):
        # Un éditeur banni (publisher_profile.is_active=False) garde accès à
        # son tableau de bord (avertissements, historique) mais ne peut plus
        # publier de nouveau contenu tant que son compte n'est pas réactivé
        # par un administrateur. Auparavant, le bannissement ne faisait que
        # le masquer de l'annuaire public sans réellement bloquer ses actions.
        profile = getattr(self.request.user, 'publisher_profile', None)
        if profile and not profile.is_active:
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied(
                "Votre compte éditeur est actuellement suspendu par un administrateur. "
                "Vous ne pouvez pas publier de nouveau contenu."
            )
        serializer.save()


class PublicationUpdateView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAuthenticated, IsOwnerOrAdmin]

    def get_serializer_class(self):
        return PublicationCreateSerializer

    def get_queryset(self):
        if self.request.user.role == 'admin':
            return Publication.objects.all()
        return Publication.objects.filter(publisher=self.request.user)


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
                    title=f'Nouvel avis sur « {pub.title[:40]} »',
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
                    title=f'Nouveau commentaire sur « {pub.title[:40]} »',
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
        if pub.is_free or pub.prix == 0:
            return True
        if user == pub.publisher or user.role == 'admin':
            return True

        from apps.abonnements.models import Abonnement
        from apps.paiements.models import Transaction
        from django.utils import timezone

        now = timezone.now()
        if Abonnement.objects.filter(
            reader=user, status='active', end_date__gt=now
        ).filter(
            Q(publication=pub) | Q(publisher=pub.publisher)
        ).exists():
            return True

        return Transaction.objects.filter(
            payer=user,
            publication=pub,
            type_transaction='purchase',
            status='success'
        ).exists()


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

    Permet d'uploader n'importe quel fichier média (image, PDF, vidéo)
    et de retourner son URL absolue sur le serveur.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        file_obj = request.FILES.get('file')
        if not file_obj:
            return Response({'error': 'Aucun fichier fourni.'}, status=status.HTTP_400_BAD_REQUEST)

        from django.core.files.storage import default_storage
        from django.conf import settings

        file_name = default_storage.save(f"publications/uploads/{file_obj.name}", file_obj)
        file_url = default_storage.url(file_name)

        # Si l'URL est déjà absolue (ex: Supabase → https://xxx.supabase.co/...)
        # on la retourne telle quelle sans préfixer avec le domaine Render.
        if file_url.startswith(('http://', 'https://')):
            url = file_url
        else:
            url = request.build_absolute_uri(file_url)

        return Response({'url': url}, status=status.HTTP_201_CREATED)
