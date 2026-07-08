from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Q
from django.shortcuts import get_object_or_404
from .models import Publication, Category, Review
from .serializers import (
    PublicationSerializer, PublicationCreateSerializer,
    CategorySerializer, ReviewSerializer,
)
from .serializers import ConversationSerializer
from .models import ConversationRead, HiddenConversation
from apps.accounts.permissions import IsAdmin, IsPublisher, IsOwnerOrAdmin


class CategoryListView(generics.ListCreateAPIView):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer

    def get_permissions(self):
        if self.request.method == 'POST':
            return [permissions.IsAuthenticated(), IsAdmin()]
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
            qs = qs.filter(category__slug=category)
        if pub_type:
            qs = qs.filter(pub_type=pub_type)
        if is_free is not None:
            qs = qs.filter(is_free=(is_free.lower() == 'true'))
        if publisher_id:
            qs = qs.filter(publisher_id=publisher_id)
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
    serializer_class = ReviewSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        pub = Publication.objects.get(pk=self.kwargs['pk'])
        serializer.save(reader=self.request.user, publication=pub)


class ReviewListView(generics.ListAPIView):
    serializer_class = ReviewSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        return Review.objects.filter(publication_id=self.kwargs['pk']).select_related('reader')


class AdminReviewListView(generics.ListAPIView):
    """Modération : liste de tous les avis de la plateforme (admin seulement)."""
    serializer_class = ReviewSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def get_queryset(self):
        qs = Review.objects.select_related('reader', 'publication').all()
        rating = self.request.query_params.get('rating')
        if rating:
            qs = qs.filter(rating=rating)
        return qs


class AdminReviewDeleteView(generics.DestroyAPIView):
    """Suppression d'un avis inapproprié (admin seulement)."""
    queryset = Review.objects.all()
    permission_classes = [permissions.IsAuthenticated, IsAdmin]


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
        from django.utils import timezone

        now = timezone.now()
        return Abonnement.objects.filter(
            reader=user, status='active', end_date__gt=now
        ).filter(
            Q(publication=pub) | Q(publisher=pub.publisher) | Q(publication__isnull=True)
        ).exists()


class ConversationsListView(APIView):
    """Liste des conversations (articles où l'utilisateur a commenté), triées par dernier commentaire."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        # Publications where the user has left at least one review
        pub_ids = Review.objects.filter(reader=user).values_list('publication_id', flat=True).distinct()

        # Exclude hidden conversations
        hidden_ids = HiddenConversation.objects.filter(user=user).values_list('publication_id', flat=True)
        pub_ids = [pid for pid in pub_ids if pid not in set(hidden_ids)]

        publications = Publication.objects.filter(id__in=pub_ids).select_related('category', 'publisher')

        results = []
        for pub in publications:
            last_review = Review.objects.filter(publication=pub).order_by('-created_at').first()
            if not last_review:
                continue
            total = pub.reviews.count()
            # unread count
            read = ConversationRead.objects.filter(user=user, publication=pub).first()
            if read:
                unread_count = Review.objects.filter(publication=pub, created_at__gt=read.last_read_at).count()
                has_new = unread_count > 0
            else:
                unread_count = total
                has_new = total > 0

            results.append({
                'id': pub.id,
                'title': pub.title,
                'cover_image': pub.cover_image,
                'category': {'name': pub.category.name if pub.category else None},
                'last_comment_at': last_review.created_at,
                'last_comment_text': last_review.comment,
                'total_comments': total,
                'unread_count': unread_count,
                'has_new_comments': has_new,
            })

        # Sort by last_comment_at desc
        results.sort(key=lambda r: r['last_comment_at'], reverse=True)
        serializer = ConversationSerializer(results, many=True)
        return Response(serializer.data)


class ConversationMarkReadView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        user = request.user
        try:
            pub = Publication.objects.get(pk=pk)
        except Publication.DoesNotExist:
            return Response({'detail': 'Publication introuvable.'}, status=status.HTTP_404_NOT_FOUND)

        from django.utils import timezone
        now = timezone.now()
        obj, created = ConversationRead.objects.update_or_create(
            user=user, publication=pub,
            defaults={'last_read_at': now}
        )
        return Response(status=status.HTTP_204_NO_CONTENT)


class ConversationHideView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        user = request.user
        try:
            pub = Publication.objects.get(pk=pk)
        except Publication.DoesNotExist:
            return Response({'detail': 'Publication introuvable.'}, status=status.HTTP_404_NOT_FOUND)

        HiddenConversation.objects.get_or_create(user=user, publication=pub)
        return Response(status=status.HTTP_204_NO_CONTENT)

    @staticmethod
    def _has_full_access(user, pub):
        if pub.is_free or pub.prix == 0:
            return True
        if user == pub.publisher or user.role == 'admin':
            return True

        from apps.abonnements.models import Abonnement
        from django.utils import timezone

        now = timezone.now()
        return Abonnement.objects.filter(
            reader=user, status='active', end_date__gt=now
        ).filter(
            Q(publication=pub) | Q(publisher=pub.publisher) | Q(publication__isnull=True)
        ).exists()


class ReaderCategoriesView(generics.ListAPIView):
    serializer_class = CategorySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Category.objects.all().order_by('name')


class ReaderCategoryFavoriteToggleView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        category = get_object_or_404(Category, pk=pk)
        user = request.user
        if category.favorited_by.filter(pk=user.pk).exists():
            category.favorited_by.remove(user)
            favorited = False
        else:
            category.favorited_by.add(user)
            favorited = True
        return Response({'favorited': favorited})
