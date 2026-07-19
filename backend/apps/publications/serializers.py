from rest_framework import serializers
from django.core.files.storage import default_storage
from django.conf import settings
from .models import (
    Publication, Category, Review, Comment, ReaderCategory, Favorite,
)
from apps.accounts.serializers import UserSerializer


class PublicationFileField(serializers.Field):
    def __init__(self, upload_to='publications', **kwargs):
        self.upload_to = upload_to
        super().__init__(**kwargs)

    def to_representation(self, value):
        return value

    def to_internal_value(self, data):
        if not data:
            return ""
        if isinstance(data, str):
            if data.startswith('http://') or data.startswith('https://'):
                return data
            if data.startswith('/media/'):
                return data
            raise serializers.ValidationError("Saisissez une URL valide.")
        
        # Enregistrer le fichier dans media/publications/{upload_to}/
        file_name = default_storage.save(f"publications/{self.upload_to}/{data.name}", data)
        file_url = default_storage.url(file_name)
        
        request = self.context.get('request')
        if request is not None:
            return request.build_absolute_uri(file_url)
        
        backend_url = getattr(settings, 'BACKEND_URL', 'http://localhost:8000')
        return f"{backend_url.rstrip('/')}{file_url}"


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ['id', 'name', 'slug', 'description', 'icon']
        read_only_fields = ['id', 'slug']


class ReviewSerializer(serializers.ModelSerializer):
    reader_username = serializers.CharField(source='reader.username', read_only=True)
    publication_title = serializers.CharField(source='publication.title', read_only=True)

    class Meta:
        model = Review
        fields = ['id', 'reader', 'reader_username', 'publication', 'publication_title', 'rating', 'comment', 'created_at', 'updated_at']
        read_only_fields = ['reader', 'created_at', 'updated_at', 'publication']


class ConversationSerializer(serializers.Serializer):
    """Représente un article dans la page "Mes Conversations" de l'utilisateur
    connecté : un élément par article où il a laissé au moins un commentaire
    (avis), trié par date du dernier commentaire (peu importe l'auteur).
    """
    id_article = serializers.IntegerField()
    titre_article = serializers.CharField()
    date_dernier_commentaire = serializers.DateTimeField()
    nombre_total_commentaires = serializers.IntegerField()
    texte_dernier_commentaire = serializers.CharField(allow_blank=True)
    auteur_dernier_commentaire = serializers.CharField(allow_blank=True)
    cover_image = serializers.CharField(allow_blank=True)
    has_new_comments = serializers.BooleanField()
    nouveaux_commentaires_count = serializers.IntegerField()


class CommentSerializer(serializers.ModelSerializer):
    author_name = serializers.SerializerMethodField()

    class Meta:
        model = Comment
        fields = ['id', 'publication', 'author', 'author_name', 'text', 'parent', 'created_at', 'updated_at']
        read_only_fields = ['author', 'publication', 'created_at', 'updated_at']

    def get_author_name(self, obj):
        return obj.author.name or obj.author.username


class ConversationMessageSerializer(serializers.Serializer):
    """Un message unifié de la conversation d'un article : soit un avis noté
    par étoiles (le "premier message" d'un utilisateur, façon Facebook où le
    post porte une note), soit une réponse libre façon commentaire Facebook.
    """
    id = serializers.CharField()
    type = serializers.ChoiceField(choices=['review', 'comment'])
    author_id = serializers.CharField()
    author_name = serializers.CharField()
    text = serializers.CharField(allow_blank=True)
    rating = serializers.IntegerField(allow_null=True)
    parent_id = serializers.CharField(allow_null=True)
    created_at = serializers.DateTimeField()
    updated_at = serializers.DateTimeField()
    is_mine = serializers.BooleanField()


class ReaderCategorySerializer(serializers.ModelSerializer):
    articles_count = serializers.SerializerMethodField()

    class Meta:
        model = ReaderCategory
        fields = ['id', 'name', 'created_at', 'articles_count']
        read_only_fields = ['id', 'created_at']

    def get_articles_count(self, obj):
        return obj.favorites.count()


class FavoritePublicationSerializer(serializers.Serializer):
    """Article favori tel qu'affiché dans une playlist du Lecteur."""
    id = serializers.IntegerField()
    title = serializers.CharField()
    description = serializers.CharField(allow_blank=True)
    cover_image = serializers.CharField(allow_blank=True)
    category_ids = serializers.ListField(child=serializers.IntegerField())
    added_at = serializers.DateTimeField()


class PublicationSerializer(serializers.ModelSerializer):
    publisher_name = serializers.SerializerMethodField()
    category_name = serializers.CharField(source='category.name', read_only=True)
    is_subscribed = serializers.SerializerMethodField()
    file_url = serializers.SerializerMethodField()
    content = serializers.SerializerMethodField()
    average_rating = serializers.SerializerMethodField()
    reviews_count = serializers.SerializerMethodField()
    tags_list = serializers.ReadOnlyField()
    original_publisher_name = serializers.SerializerMethodField()

    class Meta:
        model = Publication
        fields = [
            'id', 'title', 'description', 'content', 'publisher', 'publisher_name',
            'category', 'category_name', 'cover_image', 'file_url', 'video_url', 'prix',
            'resell_price', 'original_publication', 'original_publisher_name',
            'status', 'pub_type', 'is_free', 'views_count', 'downloads_count',
            'tags', 'tags_list', 'average_rating', 'reviews_count', 'is_subscribed',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['publisher', 'views_count', 'downloads_count', 'created_at', 'updated_at', 'original_publication']

    def get_original_publisher_name(self, obj):
        if obj.original_publication:
            pub = obj.original_publication.publisher
            if pub.role == 'publisher' and hasattr(pub, 'publisher_profile'):
                return pub.publisher_profile.company_name
            return pub.name or pub.username
        return None

    def get_publisher_name(self, obj):
        if obj.publisher.role == 'publisher' and hasattr(obj.publisher, 'publisher_profile'):
            return obj.publisher.publisher_profile.company_name
        return obj.publisher.name or obj.publisher.username

    def get_is_subscribed(self, obj):
        return self._has_full_access(obj)

    def get_content(self, obj):
        if obj.is_free or obj.prix == 0:
            return obj.content
        if self._has_full_access(obj):
            return obj.content
        return ''

    def get_file_url(self, obj):
        """Le fichier complet n'est renvoyé que si l'utilisateur y a réellement droit.

        Ceci empêche un lecteur non abonné de récupérer l'URL du document complet
        simplement en inspectant la réponse JSON de la liste des publications —
        l'application ne doit plus se reposer uniquement sur la limite de pages
        appliquée côté client Flutter. Le fichier complet reste accessible via
        l'endpoint dédié /publications/<id>/file/ pour les utilisateurs autorisés.
        """
        if obj.is_free or obj.prix == 0:
            return obj.file_url
        if self._has_full_access(obj):
            return obj.file_url
        return ''

    def _has_full_access(self, obj):
        request = self.context.get('request')
        user = None
        if request is not None:
            user = getattr(request, 'user', None)
            if not user and hasattr(request, '_request'):
                user = getattr(request._request, 'user', None)
        if not request or not user or not getattr(user, 'is_authenticated', False):
            return False

        # Les créateurs/éditeurs ont accès à leurs propres publications
        if user == obj.publisher or user.role == 'admin':
            return True

        from apps.abonnements.models import Abonnement
        from apps.paiements.models import Transaction
        from django.utils import timezone
        from django.db.models import Q

        now = timezone.now()
        active_subs = Abonnement.objects.filter(
            reader=user,
            status='active',
            end_date__gt=now
        )

        if active_subs.filter(
            Q(publication=obj) | Q(publisher=obj.publisher)
        ).exists():
            return True

        return Transaction.objects.filter(
            payer=user,
            publication=obj,
            type_transaction='purchase',
            status='success'
        ).exists()

    def get_average_rating(self, obj):
        reviews = obj.reviews.all()
        if not reviews:
            return None
        return round(sum(r.rating for r in reviews) / len(reviews), 1)

    def get_reviews_count(self, obj):
        return obj.reviews.count()


class PublicationCreateSerializer(serializers.ModelSerializer):
    # L'éditeur peut désormais taper librement le nom de la catégorie au lieu
    # de choisir dans une liste fermée. Si `category_name` est fourni, la
    # catégorie correspondante est récupérée (insensible à la casse) ou créée
    # à la volée. Le champ `category` (id) reste accepté pour compatibilité
    # ascendante (ex : formulaires admin existants).
    category = serializers.PrimaryKeyRelatedField(
        queryset=Category.objects.all(), required=False, allow_null=True
    )
    category_name = serializers.CharField(
        required=False, allow_blank=True, write_only=True, max_length=100
    )

    cover_image = PublicationFileField(upload_to='covers', required=False, allow_null=True)
    file_url = PublicationFileField(upload_to='pdfs', required=False, allow_null=True)
    video_url = PublicationFileField(upload_to='videos', required=False, allow_null=True)

    class Meta:
        model = Publication
        fields = [
            'id', 'title', 'description', 'content', 'category', 'category_name',
            'cover_image', 'file_url', 'video_url', 'prix', 'resell_price', 'status', 'pub_type', 'is_free',
            'tags',
        ]

    def validate(self, attrs):
        category_name = (attrs.pop('category_name', '') or '').strip()
        if category_name:
            existing = Category.objects.filter(name__iexact=category_name).first()
            attrs['category'] = existing or Category.objects.create(name=category_name)
        elif self.instance is None and not attrs.get('category'):
            # Création d'un article : une catégorie est obligatoire. Pour une
            # mise à jour (self.instance existe déjà, ex: PATCH statut seul),
            # l'absence de category_name ne doit jamais bloquer : la
            # catégorie existante de l'article est simplement conservée.
            raise serializers.ValidationError(
                {'category_name': "Veuillez indiquer le nom d'une catégorie."}
            )
        return attrs

    def create(self, validated_data):
        validated_data['publisher'] = self.context['request'].user
        return super().create(validated_data)

    def update(self, instance, validated_data):
        if instance.original_publication is not None:
            # Empêcher la modification des champs clés pour une republication
            for field in ['title', 'description', 'content', 'cover_image', 'file_url', 'video_url', 'category', 'pub_type']:
                validated_data.pop(field, None)
        return super().update(instance, validated_data)

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['id'] = instance.id
        return data
