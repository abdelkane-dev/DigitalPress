import logging

from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from django.contrib.auth.password_validation import validate_password
from .models import User, PublisherProfile, PosterWarning, PasswordResetCode
from django.core.files.storage import default_storage
from django.conf import settings
from django.db import models

logger = logging.getLogger('apps')

class AvatarField(serializers.Field):
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
        
        # Save file to media/avatars/
        file_name = default_storage.save(f"avatars/{data.name}", data)
        file_url = default_storage.url(file_name)
        
        request = self.context.get('request')
        if request is not None:
            return request.build_absolute_uri(file_url)
        
        backend_url = getattr(settings, 'BACKEND_URL', 'http://localhost:8000')
        return f"{backend_url.rstrip('/')}{file_url}"


class PublisherProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = PublisherProfile
        fields = ['id', 'company_name', 'siret', 'address', 'website',
                  'bio', 'solde', 'total_earned', 'commission_rate', 'is_active']
        read_only_fields = ['solde', 'total_earned']

    def update(self, instance, validated_data):
        # ─── SÉCURITÉ CRITIQUE ───────────────────────────────────────────
        # Ce serializer est utilisé aussi bien par PublisherProfileView
        # (self-service, PATCH /accounts/me/publisher-profile/, ouvert à
        # tout éditeur pour SON PROPRE profil) que dans le flux imbriqué de
        # UserSerializer/UserDetailView (réservé aux admins). Sans ce
        # garde-fou, un éditeur banni pouvait se réactiver lui-même via
        # {"is_active": true}, ou modifier son propre taux de commission
        # via {"commission_rate": 0} pour échapper aux frais de la
        # plateforme. Ces deux champs restent donc strictement réservés
        # aux administrateurs.
        request = self.context.get('request')
        is_admin_request = bool(
            request and request.user and request.user.is_authenticated
            and request.user.role == 'admin'
        )
        if not is_admin_request:
            validated_data.pop('is_active', None)
            validated_data.pop('commission_rate', None)
        return super().update(instance, validated_data)


class PublicPublisherProfileSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)

    class Meta:
        model = PublisherProfile
        fields = ['id', 'username', 'company_name', 'website', 'address', 'bio']
        read_only_fields = ['id', 'username', 'company_name', 'website', 'address', 'bio']


class UserSerializer(serializers.ModelSerializer):
    publisher_profile = PublisherProfileSerializer(required=False)
    avatar = AvatarField(required=False, allow_null=True)
    stats = serializers.SerializerMethodField()
    preferences = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'name', 'phone', 'avatar',
                  'role', 'is_verified', 'is_active', 'solde', 'publisher_profile',
                  'date_joined', 'stats', 'preferences']
        read_only_fields = ['date_joined', 'is_verified', 'solde']

    def get_stats(self, obj):
        favorite_count = obj.favorites.count() if hasattr(obj, 'favorites') else 0
        purchase_count = obj.transactions_emises.filter(type_transaction='purchase').count()
        read_count = 0
        if hasattr(obj, 'conversation_reads'):
            read_count = obj.conversation_reads.count()
        return {
            'total_purchases': purchase_count,
            'total_reads': read_count,
            'total_bookmarks': favorite_count,
            'total_spent': float(obj.transactions_emises.filter(status='success').aggregate(models.Sum('montant_net'))['montant_net__sum'] or 0),
            'reading_streak': 0,
        }

    def get_preferences(self, obj):
        return {
            'notifications_enabled': True,
            'email_notifications': True,
            'push_notifications': True,
            'language': 'fr',
            'dark_mode': False,
        }

    def to_internal_value(self, data):
        mutable_data = data.copy() if hasattr(data, 'copy') else dict(data)
        pub_profile_data = {}
        for key in list(mutable_data.keys()):
            if key.startswith('publisher_profile_'):
                sub_key = key.replace('publisher_profile_', '')
                pub_profile_data[sub_key] = mutable_data.pop(key)[0] if isinstance(mutable_data[key], list) else mutable_data.pop(key)
            elif key.startswith('publisher_profile['):
                sub_key = key.replace('publisher_profile[', '').replace(']', '')
                pub_profile_data[sub_key] = mutable_data.pop(key)[0] if isinstance(mutable_data[key], list) else mutable_data.pop(key)

        if pub_profile_data:
            mutable_data['publisher_profile'] = pub_profile_data
        
        return super().to_internal_value(mutable_data)

    def update(self, instance, validated_data):
        # ─── SÉCURITÉ CRITIQUE ───────────────────────────────────────────
        # Ce serializer est utilisé à la fois par ProfileView (PATCH /me/,
        # accessible à n'importe quel utilisateur authentifié pour éditer
        # SON PROPRE profil) et par UserDetailView (réservée aux admins).
        # Sans ce garde-fou, n'importe quel compte pouvait s'auto-promouvoir
        # admin ou se réactiver après un bannissement simplement en envoyant
        # {"role": "admin"} ou {"is_active": true} à /accounts/me/.
        # On ne laisse passer ces deux champs sensibles que si la requête
        # est bien effectuée par un administrateur.
        request = self.context.get('request')
        is_admin_request = bool(
            request and request.user and request.user.is_authenticated
            and request.user.role == 'admin'
        )
        if not is_admin_request:
            validated_data.pop('role', None)
            validated_data.pop('is_active', None)

        profile_data = validated_data.pop('publisher_profile', None)
        instance = super().update(instance, validated_data)
        if profile_data and instance.role == 'publisher':
            if not is_admin_request:
                # Même garde-fou que PublisherProfileSerializer.update() : ce
                # chemin imbriqué fait un setattr direct et contournerait
                # sinon la protection posée là-bas.
                profile_data.pop('is_active', None)
                profile_data.pop('commission_rate', None)
            profile, _ = PublisherProfile.objects.get_or_create(
                user=instance,
                defaults={'company_name': instance.name or instance.username}
            )
            for attr, value in profile_data.items():
                setattr(profile, attr, value)
            profile.save()
        return instance



class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, validators=[validate_password])
    password2 = serializers.CharField(write_only=True, label='Confirmer le mot de passe')
    company_name = serializers.CharField(write_only=True, required=False, allow_blank=True)
    name = serializers.CharField(required=False, allow_blank=True)

    class Meta:
        model = User
        fields = ['username', 'email', 'password', 'password2',
                  'name', 'phone', 'role', 'company_name']

    def validate(self, attrs):
        if attrs['password'] != attrs.pop('password2'):
            raise serializers.ValidationError({'password': 'Les mots de passe ne correspondent pas.'})
        if attrs.get('role') == 'publisher' and not attrs.get('company_name', '').strip():
            raise serializers.ValidationError({'company_name': 'Le nom de l\'entreprise est requis pour un éditeur.'})
        return attrs

    def create(self, validated_data):
        company_name = validated_data.pop('company_name', '')
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data.get('email', ''),
            password=validated_data['password'],
            name=validated_data.get('name', ''),
            phone=validated_data.get('phone', ''),
            role=validated_data.get('role', 'reader'),
            billing_address='',
            billing_phone='',
        )
        if user.role == 'publisher':
            PublisherProfile.objects.create(
                user=user,
                company_name=company_name or user.name or user.username,
            )
        return user


class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token['role'] = user.role
        token['username'] = user.username
        token['name'] = user.name
        return token

    def validate(self, attrs):
        username = attrs.get('username', '')
        if '@' in username:
            user = User.objects.filter(email__iexact=username).first()
            if user:
                logger.warning(
                    'Login attempt via email for %s: mapped to username=%s, is_active=%s, is_verified=%s',
                    username,
                    user.username,
                    user.is_active,
                    user.is_verified,
                )
                attrs['username'] = user.username
            else:
                logger.warning(
                    'Login attempt via email for %s: no matching user found',
                    username,
                )
        data = super().validate(attrs)
        data['user'] = UserSerializer(self.user).data
        return data


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(required=True)
    new_password = serializers.CharField(required=True, validators=[validate_password])

    def validate_old_password(self, value):
        user = self.context['request'].user
        if not user.check_password(value):
            raise serializers.ValidationError('Ancien mot de passe incorrect.')
        return value


class PosterWarningSerializer(serializers.ModelSerializer):
    publisher_username = serializers.CharField(source='publisher.username', read_only=True)
    issued_by_username = serializers.CharField(source='issued_by.username', read_only=True, default='')

    class Meta:
        model = PosterWarning
        fields = [
            'id', 'publisher', 'publisher_username', 'issued_by_username',
            'reason', 'severity', 'created_at',
        ]
        read_only_fields = ['id', 'created_at']


class PosterWarningCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = PosterWarning
        fields = ['id', 'publisher', 'reason', 'severity', 'created_at']
        read_only_fields = ['id', 'created_at']

    def validate_publisher(self, value):
        if value.role != 'publisher':
            raise serializers.ValidationError("Cet utilisateur n'est pas un éditeur.")
        return value


class PasswordResetRequestSerializer(serializers.Serializer):
    email = serializers.EmailField()


class PasswordResetVerifySerializer(serializers.Serializer):
    email = serializers.EmailField()
    code = serializers.CharField(min_length=6, max_length=6)


class PasswordResetConfirmSerializer(serializers.Serializer):
    email = serializers.EmailField()
    code = serializers.CharField(min_length=6, max_length=6)
    new_password = serializers.CharField(validators=[validate_password])
