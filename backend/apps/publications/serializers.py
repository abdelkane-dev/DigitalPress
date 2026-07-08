from rest_framework import serializers
from .models import Publication, Category, Review
from apps.accounts.serializers import UserSerializer
from .models import ConversationRead, HiddenConversation


class CategorySerializer(serializers.ModelSerializer):
    is_favorite = serializers.SerializerMethodField()

    class Meta:
        model = Category
        fields = ['id', 'name', 'slug', 'description', 'icon', 'is_favorite']
        read_only_fields = ['id', 'slug', 'is_favorite']

    def get_is_favorite(self, obj):
        request = self.context.get('request')
        if request and request.user and request.user.is_authenticated:
            return obj.favorited_by.filter(pk=request.user.pk).exists()
        return False


class ReviewSerializer(serializers.ModelSerializer):
    reader_username = serializers.CharField(source='reader.username', read_only=True)
    publication_title = serializers.CharField(source='publication.title', read_only=True)

    class Meta:
        model = Review
        fields = ['id', 'reader_username', 'publication', 'publication_title', 'rating', 'comment', 'created_at']
        read_only_fields = ['created_at', 'publication']


class PublicationSerializer(serializers.ModelSerializer):
    publisher_name = serializers.SerializerMethodField()
    category_name = serializers.CharField(source='category.name', read_only=True)
    is_subscribed = serializers.SerializerMethodField()
    file_url = serializers.SerializerMethodField()
    average_rating = serializers.SerializerMethodField()
    reviews_count = serializers.SerializerMethodField()
    tags_list = serializers.ReadOnlyField()

    class Meta:
        model = Publication
        fields = [
            'id', 'title', 'description', 'content', 'publisher', 'publisher_name',
            'category', 'category_name', 'cover_image', 'file_url', 'prix',
            'status', 'pub_type', 'is_free', 'views_count', 'downloads_count',
            'tags', 'tags_list', 'average_rating', 'reviews_count', 'is_subscribed',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['publisher', 'views_count', 'downloads_count', 'created_at', 'updated_at']

    def get_publisher_name(self, obj):
        if obj.publisher.role == 'publisher' and hasattr(obj.publisher, 'publisher_profile'):
            return obj.publisher.publisher_profile.company_name
        return obj.publisher.name or obj.publisher.username

    def get_is_subscribed(self, obj):
        return self._has_full_access(obj)

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
        if not request or not request.user or not request.user.is_authenticated:
            return False

        # Les créateurs/éditeurs ont accès à leurs propres publications
        if request.user == obj.publisher or request.user.role == 'admin':
            return True

        from apps.abonnements.models import Abonnement
        from django.utils import timezone
        from django.db.models import Q

        now = timezone.now()
        active_subs = Abonnement.objects.filter(
            reader=request.user,
            status='active',
            end_date__gt=now
        )

        return active_subs.filter(
            Q(publication=obj) | Q(publisher=obj.publisher) | Q(publication__isnull=True)
        ).exists()

    def get_average_rating(self, obj):
        reviews = obj.reviews.all()
        if not reviews:
            return None
        return round(sum(r.rating for r in reviews) / len(reviews), 1)

    def get_reviews_count(self, obj):
        return obj.reviews.count()


class PublicationCreateSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(write_only=True, required=False, allow_blank=True)

    class Meta:
        model = Publication
        fields = [
            'id', 'title', 'description', 'content', 'category', 'category_name', 'cover_image',
            'file_url', 'prix', 'status', 'pub_type', 'is_free', 'tags',
        ]
        read_only_fields = ['id']

    def validate(self, attrs):
        category_name = attrs.pop('category_name', '').strip()
        if category_name and not attrs.get('category'):
            category = Category.objects.filter(name__iexact=category_name).first()
            if not category:
                category = Category.objects.create(name=category_name)
            attrs['category'] = category
        return attrs

    def create(self, validated_data):
        validated_data['publisher'] = self.context['request'].user
        return super().create(validated_data)


class ConversationSerializer(serializers.Serializer):
    id = serializers.IntegerField(source='id')
    publication_id = serializers.IntegerField(source='id')
    title = serializers.CharField(source='title')
    cover_image = serializers.CharField(source='cover_image')
    category_name = serializers.CharField(source='category.name', allow_null=True)
    last_comment_at = serializers.DateTimeField()
    last_comment_text = serializers.CharField(allow_blank=True, allow_null=True)
    total_comments = serializers.IntegerField()
    unread_count = serializers.IntegerField()
    has_new_comments = serializers.BooleanField()
