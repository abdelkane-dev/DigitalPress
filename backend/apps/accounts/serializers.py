import logging

from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from django.contrib.auth.password_validation import validate_password
from .models import User, PublisherProfile, PosterWarning, PasswordResetCode, PublisherVerification
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

        # ─── SÉCURITÉ : même faille que MediaUploadView (voir ce commentaire
        # dans apps/publications/views.py) — un avatar n'a besoin que d'être
        # une image, de taille raisonnable.
        import os
        ext = os.path.splitext(data.name)[1].lower()
        if ext not in {'.jpg', '.jpeg', '.png', '.gif', '.webp'}:
            raise serializers.ValidationError(f"Type d'image non autorisé ({ext or 'inconnu'}).")
        if data.size > 5 * 1024 * 1024:  # 5 Mo
            raise serializers.ValidationError("Image trop volumineuse (5 Mo maximum).")

        # Save file to media/avatars/
        file_name = default_storage.save(f"avatars/{data.name}", data)
        file_url = default_storage.url(file_name)
        
        request = self.context.get('request')
        if request is not None:
            return request.build_absolute_uri(file_url)
        
        backend_url = getattr(settings, 'BACKEND_URL', 'http://localhost:8000')
        return f"{backend_url.rstrip('/')}{file_url}"


class PublisherProfileSerializer(serializers.ModelSerializer):
    # Réutilise la même logique d'upload d'image que l'avatar (whitelist
    # d'extensions + taille max) pour la couverture de la page publique.
    cover_image = AvatarField(required=False, allow_null=True)
    # Le taux de commission affiché est celui du PALIER actif de l'éditeur
    # (Basique 20 % / Standard 15 % / Premium 10 %), pas une valeur figée :
    # il évolue tout seul quand l'éditeur change de palier.
    commission_rate = serializers.SerializerMethodField()
    platform_plan_name = serializers.SerializerMethodField()

    class Meta:
        model = PublisherProfile
        fields = ['id', 'company_name', 'siret', 'address', 'website',
                  'bio', 'cover_image', 'solde', 'total_earned', 'commission_rate',
                  'platform_plan_name', 'is_active']
        read_only_fields = ['solde', 'total_earned']

    @staticmethod
    def _active_plan(obj):
        sub = obj.user.platform_subscriptions.filter(
            status='active'
        ).select_related('plan').first()
        return sub.plan if (sub and sub.plan) else None

    def get_commission_rate(self, obj):
        plan = self._active_plan(obj)
        if plan is not None:
            return float(plan.commission_rate)
        return float(obj.commission_rate or 0)

    def get_platform_plan_name(self, obj):
        plan = self._active_plan(obj)
        return plan.name if plan else None

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
        # Réactivation par un admin (is_active=True) : plus aucune condition
        # à vérifier — l'accès plateforme est gratuit et automatique dès la
        # création du compte (voir apps.abonnements.services), il n'y a
        # donc plus d'« abonnement à payer » qui pourrait bloquer cette
        # réactivation. Seule la décision de l'admin compte désormais.
        return super().update(instance, validated_data)


class PublicPublisherProfileSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    avatar = serializers.SerializerMethodField()
    is_active = serializers.BooleanField(read_only=True)
    published_articles = serializers.SerializerMethodField()
    total_views = serializers.SerializerMethodField()
    subscriber_count = serializers.SerializerMethodField()
    has_verified_badge = serializers.SerializerMethodField()
    # Taux de commission selon le palier actif + nom du palier — affiché
    # sur le profil public de l'éditeur (demande explicite).
    commission_rate = serializers.SerializerMethodField()
    platform_plan_name = serializers.SerializerMethodField()

    class Meta:
        model = PublisherProfile
        fields = [
            'id', 'username', 'company_name', 'website', 'address', 'bio',
            'avatar', 'cover_image',
            'is_active', 'published_articles', 'total_views', 'subscriber_count',
            'has_verified_badge', 'commission_rate', 'platform_plan_name',
        ]
        read_only_fields = fields

    def get_has_verified_badge(self, obj):
        # ─── AVANTAGE RÉEL DU PLAN : BADGE VÉRIFIÉ ──────────────────────
        active_sub = obj.user.platform_subscriptions.filter(
            status='active'
        ).select_related('plan').first()
        return bool(active_sub and active_sub.plan and active_sub.plan.has_verified_badge)

    def get_commission_rate(self, obj):
        active_sub = obj.user.platform_subscriptions.filter(
            status='active'
        ).select_related('plan').first()
        if active_sub and active_sub.plan:
            return float(active_sub.plan.commission_rate)
        return float(obj.commission_rate or 0)

    def get_platform_plan_name(self, obj):
        active_sub = obj.user.platform_subscriptions.filter(
            status='active'
        ).select_related('plan').first()
        return active_sub.plan.name if (active_sub and active_sub.plan) else None

    # ─── Ces 4 champs manquaient totalement avant ce correctif : le widget
    # Flutter (poster_profile_screen.dart) les lisait déjà (data['avatar'],
    # data['is_active'], etc.) mais recevait toujours null/absent — d'où
    # des stats à 0 et un badge "Compte suspendu" affiché à tort sur TOUS
    # les profils publics, même actifs.
    def get_avatar(self, obj):
        # User.avatar est un URLField (déjà une chaîne, pas un FileField) :
        # la valeur stockée par AvatarField.to_internal_value() est déjà une
        # URL absolue complète.
        return obj.user.avatar or None

    def get_published_articles(self, obj):
        return obj.user.publications.filter(status='published').count()

    def get_total_views(self, obj):
        from django.db.models import Sum
        total = obj.user.publications.filter(status='published').aggregate(
            total=Sum('views_count')
        )['total']
        return total or 0

    def get_subscriber_count(self, obj):
        from apps.abonnements.models import Abonnement
        return Abonnement.objects.filter(
            publisher=obj.user, status='active'
        ).values('reader').distinct().count()


class UserSerializer(serializers.ModelSerializer):
    publisher_profile = PublisherProfileSerializer(required=False)
    avatar = AvatarField(required=False, allow_null=True)
    stats = serializers.SerializerMethodField()
    preferences = serializers.SerializerMethodField()
    verification_status = serializers.SerializerMethodField()
    platform_plan_name = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'name', 'phone', 'avatar',
                  'role', 'is_verified', 'is_active', 'solde', 'publisher_profile',
                  'date_joined', 'stats', 'preferences', 'verification_status',
                  'platform_plan_name']
        read_only_fields = ['date_joined', 'is_verified', 'solde']

    def get_verification_status(self, obj):
        # 'not_submitted' | 'pending' | 'approved' | 'rejected'. Le router
        # Flutter s'en sert pour l'étape 1/3 de l'onboarding éditeur — non
        # pertinent pour les autres rôles (toujours 'not_submitted' pour eux,
        # sans effet puisque le router ne teste ça que si role == publisher).
        verification = getattr(obj, 'verification', None)
        return verification.status if verification else 'not_submitted'

    def get_platform_plan_name(self, obj):
        # ─── CORRECTIF : badge de profil incorrect ──────────────────────
        # Le badge affiché sur l'écran de profil (voir profile_screen.dart)
        # affichait "Membre Premium" en dur pour TOUT utilisateur vérifié
        # (lecteur, éditeur, admin confondus) au lieu du vrai palier de
        # l'éditeur (Basique/Standard/Premium — voir
        # apps.abonnements.services.sync_publisher_tier). Null pour les
        # non-éditeurs : le Flutter décide alors du libellé adapté à leur
        # rôle ('Compte vérifié' pour un lecteur, 'Super Utilisateur' pour
        # un admin), au lieu d'un palier qui ne les concerne pas.
        if obj.role != 'publisher':
            return None
        sub = obj.platform_subscriptions.filter(status='active').select_related('plan').first()
        return sub.plan.name if (sub and sub.plan) else None

    def get_stats(self, obj):
        # ─── STATS ADAPTÉES AU RÔLE ─────────────────────────────────────
        # Lecteur : achats / lectures / favoris / dépenses.
        # Éditeur : publications / vues / abonnés (son activité d'éditeur).
        # Admin : utilisateurs / revenus / transactions (il n'achète rien,
        # ses stats personnelles d'achat n'auraient aucun sens — l'app
        # affiche alors ses stats globales plateforme).
        favorite_count = obj.favorites.count() if hasattr(obj, 'favorites') else 0
        # ─── CORRECTIF : compteur « Achats » du profil ────────────────────
        # Ne compter que les achats RÉUSSIS (status='success'). Sans ce
        # filtre, des transactions en attente/échouées gonflaient le compteur
        # — et surtout, le profil affichait des stats figées au moment de la
        # connexion (voir ProfileScreen, qui recharge désormais le profil à
        # l'ouverture pour que le compteur reflète les achats récents).
        purchase_count = obj.transactions_emises.filter(
            type_transaction='purchase', status='success'
        ).count()
        read_count = 0
        if hasattr(obj, 'conversation_reads'):
            read_count = obj.conversation_reads.count()
        stats = {
            'total_purchases': purchase_count,
            'total_reads': read_count,
            'total_bookmarks': favorite_count,
            'total_spent': float(obj.transactions_emises.filter(status='success').aggregate(models.Sum('montant_net'))['montant_net__sum'] or 0),
            'reading_streak': 0,
        }
        if obj.role == 'publisher':
            from django.db.models import Sum as _Sum
            pubs = obj.publications.filter(status='published')
            stats['total_publications'] = pubs.count()
            stats['total_views'] = pubs.aggregate(total=_Sum('views_count'))['total'] or 0
            from apps.abonnements.models import Abonnement
            stats['total_subscribers'] = Abonnement.objects.filter(
                publisher=obj, status='active'
            ).values('reader').distinct().count()
        elif obj.role == 'admin':
            from django.contrib.auth import get_user_model
            from apps.paiements.models import Transaction
            UserModel = get_user_model()
            stats['total_users'] = UserModel.objects.count()
            stats['total_revenue'] = float(Transaction.objects.filter(
                status='success'
            ).aggregate(models.Sum('montant_net'))['montant_net__sum'] or 0)
            stats['total_transactions'] = Transaction.objects.filter(
                status='success'
            ).count()
        return stats

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
        # ─── SÉCURITÉ CRITIQUE ───────────────────────────────────────────
        # Ce endpoint est PUBLIC (AllowAny). L'auto-inscription est
        # autorisée pour deux rôles seulement : `reader` (lecteur) et
        # `publisher` (éditeur). Un éditeur s'inscrit lui-même, puis se
        # connecte et poursuit son processus initial (vérification de
        # légitimité, voir MyPublisherVerificationView). Le rôle `admin`
        # ne peut JAMAIS être créé via une route publique — il n'est
        # attribué que manuellement (shell/superuser).
        role = (attrs.get('role') or 'reader').strip().lower()
        if role not in ('reader', 'publisher'):
            raise serializers.ValidationError(
                {'role': "Rôle invalide. Choisissez 'reader' ou 'publisher'."}
            )
        attrs['role'] = role
        # ─── NUMÉRO DE TÉLÉPHONE OBLIGATOIRE (note Dr. Sissoko) ──────────
        # « Exiger le numéro de téléphone à la création de tout type de
        # compte » : c'est un moyen de contact réel et un premier rempart
        # contre les comptes fantômes. Requis pour TOUS les rôles.
        phone = (attrs.get('phone') or '').strip()
        if not phone:
            raise serializers.ValidationError(
                {'phone': 'Le numéro de téléphone est requis pour créer un compte.'}
            )
        attrs['phone'] = phone
        return attrs

    def create(self, validated_data):
        role = validated_data.pop('role', 'reader')
        company_name = validated_data.pop('company_name', None) or ''
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data.get('email', ''),
            password=validated_data['password'],
            name=validated_data.get('name', ''),
            phone=validated_data.get('phone', ''),
            role=role,
            # Le compte est créé NON VÉRIFIÉ : l'activation se fait par la
            # validation du code OTP envoyé par email (voir
            # EmailVerificationCode / VerifyEmailView) — exigence pour TOUS
            # les types de profils (note Dr. Sissoko). La connexion reste
            # bloquée tant que is_verified=False (voir
            # CustomTokenObtainPairSerializer.validate).
            is_verified=False,
            billing_address='',
            billing_phone='',
        )
        if role == 'publisher':
            # Même flux que la création par l'admin : accès immédiat à la
            # plateforme (aucun paiement requis), profil d'entreprise créé
            # avec la raison sociale fournie, palier initial « Basique ».
            PublisherProfile.objects.create(
                user=user,
                company_name=company_name or user.name or user.username,
                is_active=True,
            )
            from apps.abonnements.services import sync_publisher_tier
            sync_publisher_tier(user)

        # ─── OTP D'ACTIVATION PAR EMAIL (15 min, note Dr. Sissoko) ───────
        # Le code est généré, stocké haché et envoyé par email ; la page
        # d'inscription bascule ensuite sur l'écran de saisie du code.
        try:
            from .models import EmailVerificationCode
            raw_code = EmailVerificationCode.issue_for(user, validity_minutes=15)
            from django.core.mail import send_mail as _send_mail
            from django.conf import settings as _settings
            _send_mail(
                subject='DigitalPress — Activez votre compte',
                message=(
                    f"Bienvenue sur DigitalPress !\n\n"
                    f"Votre code d'activation est : {raw_code}\n"
                    f"Il expire dans 15 minutes. Saisissez-le dans l'application "
                    f"pour activer votre compte.\n\n"
                    f"Si vous n'êtes pas à l'origine de cette inscription, ignorez cet email."
                ),
                from_email=getattr(_settings, 'DEFAULT_FROM_EMAIL', 'no-reply@digitalpress.local'),
                recipient_list=[user.email],
                fail_silently=True,
            )
        except Exception:
            logger.exception('Échec envoi email d\'activation à %s', user.email)
        return user


class AdminCreatePublisherSerializer(serializers.ModelSerializer):
    """Création d'un compte Éditeur — réservée à l'administrateur.

    C'est la seule façon de créer un compte avec role='publisher' :
    l'auto-inscription publique (RegisterSerializer) force désormais
    role='reader' quoi qu'il arrive. L'éditeur créé ici a un accès immédiat
    à la plateforme (aucun paiement requis) et démarre au palier "Basique",
    qui évolue automatiquement selon son activité (voir apps.abonnements.services).
    """
    password = serializers.CharField(write_only=True, validators=[validate_password])
    company_name = serializers.CharField(write_only=True, required=True)

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'password', 'name', 'phone', 'company_name']

    def create(self, validated_data):
        company_name = validated_data.pop('company_name')
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data.get('email', ''),
            password=validated_data['password'],
            name=validated_data.get('name', ''),
            phone=validated_data.get('phone', ''),
            role='publisher',
            is_verified=True,
            billing_address='',
            billing_phone='',
        )
        PublisherProfile.objects.create(
            user=user,
            company_name=company_name,
            is_active=True,  # accès immédiat, aucun paiement requis
        )
        from apps.abonnements.services import sync_publisher_tier
        sync_publisher_tier(user)  # démarre au palier "Basique"
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
        # ─── ACTIVATION DU COMPTE OBLIGATOIRE (note Dr. Sissoko) ──────────
        # Un compte créé par inscription doit avoir validé son email (OTP)
        # avant de pouvoir se connecter — exigence pour TOUS les types de
        # profils. Les comptes existants ont été marqués vérifiés par la
        # migration de données, donc personne n'est bloqué rétroactivement.
        # (Les comptes Google/Facebook sont vérifiés par le fournisseur.)
        user = self.user
        if user and not getattr(user, 'is_verified', False):
            raise serializers.ValidationError(
                {
                    'detail': (
                        "Votre compte n'est pas encore activé. Saisissez le code de "
                        "vérification envoyé à votre email pour activer votre compte."
                    ),
                    'code': 'email_not_verified',
                }
            )
        data['user'] = UserSerializer(user).data
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


# ─── ÉTAPE 1/3 : FORMULAIRE DE VÉRIFICATION ÉDITEUR ──────────────────────

class PublisherVerificationSerializer(serializers.ModelSerializer):
    publisher_username = serializers.CharField(source='user.username', read_only=True)
    is_overdue = serializers.ReadOnlyField()

    class Meta:
        model = PublisherVerification
        fields = [
            'id', 'publisher_username', 'legal_company_name', 'registration_number',
            'tax_id', 'official_address', 'city', 'country', 'phone_number',
            'legal_representative_name', 'legal_representative_id_number',
            'press_accreditation_number', 'website', 'id_document_url',
            'registration_document_url', 'additional_document_url',
            'status', 'rejection_reason', 'submitted_at', 'reviewed_at',
            'is_overdue',
        ]
        read_only_fields = [
            'id', 'publisher_username', 'status', 'rejection_reason',
            'submitted_at', 'reviewed_at', 'is_overdue',
        ]


class PublisherVerificationSubmitSerializer(serializers.ModelSerializer):
    """Soumission (ou re-soumission après rejet) par l'éditeur lui-même."""
    class Meta:
        model = PublisherVerification
        fields = [
            'legal_company_name', 'registration_number', 'tax_id',
            'official_address', 'city', 'country', 'phone_number',
            'legal_representative_name', 'legal_representative_id_number',
            'press_accreditation_number', 'website', 'id_document_url',
            'registration_document_url', 'additional_document_url',
        ]

    def create(self, validated_data):
        user = self.context['request'].user
        # Re-soumission après rejet : on met à jour l'enregistrement existant
        # et on repasse en 'pending' plutôt que d'en créer un second.
        obj, _ = PublisherVerification.objects.update_or_create(
            user=user,
            defaults={
                **validated_data,
                'status': 'pending',
                'rejection_reason': '',
                'reviewed_at': None,
                'reviewed_by': None,
            },
        )
        return obj


class PublisherVerificationReviewSerializer(serializers.Serializer):
    """Décision admin : approuver ou rejeter une vérification."""
    decision = serializers.ChoiceField(choices=['approved', 'rejected'])
    rejection_reason = serializers.CharField(required=False, allow_blank=True)

    def validate(self, attrs):
        if attrs['decision'] == 'rejected' and not attrs.get('rejection_reason', '').strip():
            raise serializers.ValidationError(
                {'rejection_reason': 'Un motif est requis pour rejeter une vérification.'}
            )
        return attrs


class SocialLoginSerializer(serializers.Serializer):
    """Validation de l'authentification via un fournisseur social (Google, Facebook)."""
    provider = serializers.ChoiceField(choices=['google', 'facebook'])
    email = serializers.EmailField()
    name = serializers.CharField(required=False, allow_blank=True)
    provider_id = serializers.CharField(required=False, allow_blank=True)
    id_token = serializers.CharField(required=False, allow_blank=True)

