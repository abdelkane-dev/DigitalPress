import logging
import os
import requests
from django.shortcuts import get_object_or_404
from django.db.models import Q

from rest_framework import generics, status, permissions
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework_simplejwt.tokens import RefreshToken
from django.conf import settings
from django.contrib.auth import update_session_auth_hash
from django.utils.crypto import get_random_string
from django.core.mail import send_mail
from django.utils import timezone
from .models import User, PublisherProfile, PosterWarning, PasswordResetCode, PublisherVerification
from apps.notifications.models import Notification
from .serializers import (
    UserSerializer, RegisterSerializer, AdminCreatePublisherSerializer,
    CustomTokenObtainPairSerializer, ChangePasswordSerializer,
    PublisherProfileSerializer, PublicPublisherProfileSerializer,
    PosterWarningSerializer, PosterWarningCreateSerializer,
    PasswordResetRequestSerializer, PasswordResetVerifySerializer,
    PasswordResetConfirmSerializer,
    PublisherVerificationSerializer, PublisherVerificationSubmitSerializer,
    PublisherVerificationReviewSerializer, SocialLoginSerializer,
)
from .permissions import IsAdmin, IsPublisher


def _issue_and_send_activation_code(user):
    """Génère un OTP d'activation (15 min), l'envoie par email et le
    retourne en clair. Centralise le code partagé entre l'inscription
    classique, le renvoi de code et les connexions Google/Facebook : un
    compte créé via un fournisseur social doit désormais activer son email
    comme n'importe quel autre compte (demande explicite)."""
    from .models import EmailVerificationCode
    raw_code = EmailVerificationCode.issue_for(user, validity_minutes=15)
    try:
        send_mail(
            subject='DigitalPress — Activez votre compte',
            message=(
                f"Bienvenue sur DigitalPress !\n\n"
                f"Votre code d'activation est : {raw_code}\n"
                f"Il expire dans 15 minutes. Saisissez-le dans l'application "
                f"pour activer votre compte.\n\n"
                f"Si vous n'êtes pas à l'origine de cette inscription, ignorez cet email."
            ),
            from_email=getattr(settings, 'DEFAULT_FROM_EMAIL', 'no-reply@digitalpress.local'),
            recipient_list=[user.email],
            fail_silently=True,
        )
    except Exception:
        logger.exception('Échec envoi email d\'activation à %s', user.email)
    return raw_code


class CustomTokenObtainPairView(TokenObtainPairView):
    serializer_class = CustomTokenObtainPairSerializer
    throttle_scope = 'auth'
    throttle_classes = [ScopedRateThrottle]


class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]
    throttle_scope = 'auth'
    throttle_classes = [ScopedRateThrottle]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        data = UserSerializer(user).data
        # ─── ACTIVATION PAR EMAIL (note Dr. Sissoko) ──────────────────────
        # Le compte vient d'être créé NON VÉRIFIÉ : l'app doit basculer sur
        # l'écran de saisie du code OTP (15 min) plutôt que sur la page de
        # connexion, sinon l'utilisateur ne pourrait pas se connecter.
        data['email_verification_required'] = True
        return Response(data, status=status.HTTP_201_CREATED)


class VerifyEmailView(APIView):
    """POST {'email': ..., 'code': '123456'} — valide l'OTP d'activation
    reçu par email et active le compte (is_verified=True). Le code a une
    durée de vie de 15 minutes et expire après 5 tentatives ratées.
    Répond toujours avec le même message d'erreur générique pour ne jamais
    révéler si un email existe."""
    permission_classes = [permissions.AllowAny]
    throttle_scope = 'auth'
    throttle_classes = [ScopedRateThrottle]

    def post(self, request):
        email = (request.data.get('email') or '').strip().lower()
        code = (request.data.get('code') or '').strip()
        generic_error = {'code': 'Code invalide ou expiré.'}

        if not email or not code:
            return Response(generic_error, status=status.HTTP_400_BAD_REQUEST)

        user = User.objects.filter(email__iexact=email).first()
        if not user:
            return Response(generic_error, status=status.HTTP_400_BAD_REQUEST)

        if user.is_verified:
            return Response({'message': 'Compte déjà activé.', 'verified': True})

        from .models import EmailVerificationCode
        verification = EmailVerificationCode.objects.filter(
            user=user, is_used=False
        ).order_by('-created_at').first()
        if not verification or not verification.is_valid():
            return Response(generic_error, status=status.HTTP_400_BAD_REQUEST)

        if verification.code_hash != EmailVerificationCode.hash_code(code):
            verification.attempts += 1
            verification.save(update_fields=['attempts'])
            return Response(generic_error, status=status.HTTP_400_BAD_REQUEST)

        verification.is_used = True
        verification.save(update_fields=['is_used'])
        # Invalide tous les autres codes en attente pour ce compte.
        EmailVerificationCode.objects.filter(user=user, is_used=False).update(is_used=True)
        user.is_verified = True
        user.save(update_fields=['is_verified'])

        return Response({'message': 'Compte activé avec succès. Vous pouvez vous connecter.', 'verified': True})


class ResendEmailVerificationView(APIView):
    """POST {'email': ...} — renvoie un nouveau code OTP (15 min) et
    invalide le précédent. Limité par le throttle 'auth' (anti-spam)."""
    permission_classes = [permissions.AllowAny]
    throttle_scope = 'auth'
    throttle_classes = [ScopedRateThrottle]

    def post(self, request):
        email = (request.data.get('email') or '').strip()
        user = User.objects.filter(email__iexact=email).first()
        if not user:
            # Même réponse que pour un compte existant : pas d'énumération.
            return Response({'message': "Si un compte existe avec cet email, un nouveau code vient d'être envoyé."})
        if user.is_verified:
            return Response({'message': 'Ce compte est déjà activé.'})

        from .models import EmailVerificationCode
        raw_code = EmailVerificationCode.issue_for(user, validity_minutes=15)
        try:
            from django.core.mail import send_mail as _send_mail
            from django.conf import settings as _settings
            _send_mail(
                subject='DigitalPress — Activez votre compte',
                message=(
                    f"Voici votre nouveau code d'activation : {raw_code}\n"
                    f"Il expire dans 15 minutes.\n\nL'équipe DigitalPress"
                ),
                from_email=getattr(_settings, 'DEFAULT_FROM_EMAIL', 'no-reply@digitalpress.local'),
                recipient_list=[email],
                fail_silently=True,
            )
        except Exception:
            logger.exception('Échec renvoi email d\'activation à %s', email)
        return Response({'message': 'Un nouveau code vient d\'être envoyé par email.'})


class AdminCreatePublisherView(generics.CreateAPIView):
    """Création d'un compte Éditeur — réservée à l'administrateur (IsAdmin).

    Le compte est créé avec PublisherProfile.is_active=True : l'éditeur peut
    se connecter avec les identifiants fournis par l'admin et publier
    immédiatement, sans paiement. Il démarre au palier "Basique" et
    progresse automatiquement (voir apps.abonnements.services).
    """
    queryset = User.objects.all()
    serializer_class = AdminCreatePublisherSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response(UserSerializer(user).data, status=status.HTTP_201_CREATED)


class ProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user


class ChangePasswordView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = ChangePasswordSerializer(
            data=request.data, context={'request': request}
        )
        serializer.is_valid(raise_exception=True)
        request.user.set_password(serializer.validated_data['new_password'])
        request.user.save()
        return Response({'message': 'Mot de passe modifié avec succès.'})


class DeleteMyAccountView(APIView):
    """Suppression de compte en libre-service (exigence Apple App Store
    5.1.1(v) et Google Play : toute app permettant la création de compte
    doit permettre à l'utilisateur de le supprimer lui-même depuis l'app,
    pas seulement via un site web ou le support).

    Implémentation en anonymisation + désactivation plutôt qu'un DELETE SQL
    brutal : préserve l'intégrité des transactions/factures/publications déjà
    liées à ce compte (obligations comptables), tout en respectant l'esprit
    de la demande — les données personnelles identifiables sont effacées et
    le compte devient immédiatement inutilisable pour se reconnecter."""
    permission_classes = [permissions.IsAuthenticated]
    # Endpoint sensible (vérifie un mot de passe) : même limite de débit que
    # les endpoints d'authentification pour empêcher le brute-force.
    throttle_scope = 'auth'
    throttle_classes = [ScopedRateThrottle]

    def post(self, request):
        password = request.data.get('password', '')
        if not request.user.check_password(password):
            return Response({'error': 'Mot de passe incorrect.'}, status=status.HTTP_400_BAD_REQUEST)

        user = request.user
        anonymized_username = f"compte-supprime-{user.id}"
        user.username = anonymized_username
        user.email = f"{anonymized_username}@deleted.digitalpress.local"
        user.name = 'Compte supprimé'
        user.phone = ''
        user.avatar = ''
        user.is_active = False
        user.set_unusable_password()
        user.save()

        logger.info("Compte %s supprimé (anonymisé) par son titulaire.", user.id)
        return Response({'message': 'Votre compte a été supprimé.'})


class UserListView(generics.ListAPIView):
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def get_queryset(self):
        qs = User.objects.all()
        role = self.request.query_params.get('role')
        if role:
            qs = qs.filter(role=role)
        search = self.request.query_params.get('search')
        if search:
            qs = qs.filter(username__icontains=search) | qs.filter(email__icontains=search)
        return qs.order_by('-date_joined')


class UserDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdmin]
    queryset = User.objects.all()


class AdminUserDetailView(APIView):
    """GET /api/accounts/admin/users/<pk>/detail/

    Vue admin enrichie d'un utilisateur : identité, rôle, date de création,
    dernière activité, achats/paiements, statut (actif/suspendu/banni),
    historique des actions de modération et, pour un éditeur, son dossier
    de vérification et les informations de son agence. (Demande explicite.)"""
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def get(self, request, pk):
        from django.db.models import Sum, Count
        from apps.paiements.models import Transaction
        from .models import AccountActionLog, PublisherVerification
        from apps.comptabilite.views import effective_commission_rate

        try:
            user = User.objects.select_related('publisher_profile').get(pk=pk)
        except User.DoesNotExist:
            return Response({'error': 'Utilisateur introuvable.'}, status=404)

        tx_qs = Transaction.objects.filter(
            Q(payer=user) | Q(beneficiaire=user)
        )
        purchase_qs = Transaction.objects.filter(
            payer=user, type_transaction='purchase'
        )

        verification = None
        try:
            verification = PublisherVerification.objects.filter(user=user).order_by('-submitted_at').first()
        except PublisherVerification.DoesNotExist:
            pass

        publisher = getattr(user, 'publisher_profile', None)

        data = {
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'name': user.name,
            'phone': user.phone,
            'role': user.role,
            'is_active': user.is_active,
            'is_verified': user.is_verified,
            'date_joined': user.date_joined,
            'last_login': user.last_login,
            'avatar': user.avatar,
            # Achats / paiements
            'purchases_count': purchase_qs.filter(status='success').count(),
            'total_spent': float(purchase_qs.filter(status='success').aggregate(s=Sum('montant_net'))['s'] or 0),
            'transactions_count': tx_qs.count(),
            'recent_transactions': list(tx_qs.order_by('-created_at')[:10].values(
                'id', 'type_transaction', 'montant_brut', 'status', 'created_at'
            )),
            # Éditeur
            'publisher': {
                'company_name': publisher.company_name if publisher else None,
                'is_active': publisher.is_active if publisher else None,
                # Taux effectif du PALIER ACTIF (même valeur que celle
                # appliquée sur les transactions de cet éditeur) — demande
                # explicite : plus jamais de taux statique affiché.
                'commission_rate': (
                    float(effective_commission_rate(user)) if publisher else None
                ),
                'verification_status': verification.status if verification else None,
                'verification_submitted_at': verification.submitted_at if verification else None,
                'verification_reviewed_at': verification.reviewed_at if verification else None,
                'rejection_reason': verification.rejection_reason if verification else '',
            } if publisher else None,
            # Historique des suspensions / bannissements / réactivations
            'status_history': [
                {
                    'action': a.action,
                    'reason': a.reason,
                    'performed_by': a.performed_by.username if a.performed_by else None,
                    'created_at': a.created_at,
                }
                for a in AccountActionLog.objects.filter(user=user).select_related('performed_by')
            ],
        }
        return Response(data)


class AdminUserActionView(APIView):
    """POST /api/accounts/admin/users/<pk>/action/
    Body: {'action': 'suspend'|'ban'|'reactivate', 'reason': '...'}

    Applique une action de modération (suspendre / bannir / réactiver) et
    l'enregistre dans AccountActionLog pour l'historique du compte. Un
    compte suspendu/banni ne peut plus se connecter ; pour un éditeur, le
    profil éditeur est désactivé (plus de publication) et réactivé lors
    d'une réactivation."""
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def post(self, request, pk):
        from .models import AccountActionLog

        action = (request.data.get('action') or '').strip().lower()
        reason = (request.data.get('reason') or '').strip()
        if action not in ('suspend', 'ban', 'reactivate'):
            return Response(
                {'error': "Action invalide. Choisissez 'suspend', 'ban' ou 'reactivate'."},
                status=400,
            )
        if action in ('suspend', 'ban') and not reason:
            return Response({'error': 'Un motif est requis pour suspendre/bannir un compte.'}, status=400)

        try:
            user = User.objects.get(pk=pk)
        except User.DoesNotExist:
            return Response({'error': 'Utilisateur introuvable.'}, status=404)

        if user.id == request.user.id:
            return Response({'error': "Vous ne pouvez pas modérer votre propre compte."}, status=400)

        if action in ('suspend', 'ban'):
            user.is_active = False
            user.save(update_fields=['is_active'])
            # Un éditeur suspendu/banni ne peut plus publier non plus.
            profile = getattr(user, 'publisher_profile', None)
            if profile:
                profile.is_active = False
                profile.save(update_fields=['is_active'])
        else:  # reactivate
            user.is_active = True
            user.save(update_fields=['is_active'])
            profile = getattr(user, 'publisher_profile', None)
            if profile:
                # Réactivation : l'accès plateforme est gratuit et automatique
                # (voir apps.abonnements.services.sync_publisher_tier) — seul
                # l'admin décide désormais de la réactivation.
                profile.is_active = True
                profile.save(update_fields=['is_active'])

        AccountActionLog.objects.create(
            user=user,
            action=action,
            reason=reason,
            performed_by=request.user,
        )

        # Notifie l'utilisateur concerné (sauf si c'est lui-même).
        try:
            from apps.notifications.views import send_notification
            if action == 'reactivate':
                title = 'Compte réactivé'
                message = 'Votre compte a été réactivé par un administrateur. Vous pouvez vous reconnecter.'
            else:
                title = 'Compte ' + ('banni' if action == 'ban' else 'suspendu')
                message = f'Votre compte a été {("banni" if action == "ban" else "suspendu")}. Motif : {reason or "non précisé"}.'
            send_notification(
                user=user, type_notif='account_moderation',
                title=title, message=message,
            )
        except Exception:
            logger.exception("Echec notification moderation pour %s", user.id)

        return Response({'detail': f'Action « {action} » appliquée.'})


class PublisherProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = PublisherProfileSerializer
    permission_classes = [permissions.IsAuthenticated, IsPublisher]

    def get_object(self):
        profile, _ = PublisherProfile.objects.get_or_create(
            user=self.request.user,
            defaults={'company_name': self.request.user.name or self.request.user.username}
        )
        return profile


class PublicPublisherDetailView(generics.RetrieveAPIView):
    serializer_class = PublicPublisherProfileSerializer
    permission_classes = [permissions.AllowAny]

    def get_object(self):
        return get_object_or_404(
            PublisherProfile.objects.select_related('user').filter(is_active=True),
            user__id=self.kwargs.get('pk')
        )


class PublishersListView(generics.ListAPIView):
    """Liste de tous les éditeurs avec leurs soldes — admin seulement."""
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def list(self, request, *args, **kwargs):
        from apps.comptabilite.views import effective_commission_rate
        profiles = PublisherProfile.objects.select_related('user').all()
        data = []
        for p in profiles:
            data.append({
                'id': p.user.id,
                'username': p.user.username,
                'email': p.user.email,
                'company_name': p.company_name,
                'solde': str(p.solde),
                'total_earned': str(p.total_earned),
                # Taux effectif du palier actif (idem comptabilité).
                'commission_rate': str(effective_commission_rate(p.user)),
                'is_active': p.is_active,
                'joined': p.user.date_joined,
            })
        return Response(data)


class PublicPublishersListView(generics.ListAPIView):
    """Liste publique des éditeurs/journaux."""
    permission_classes = [permissions.AllowAny]

    def list(self, request, *args, **kwargs):
        profiles = PublisherProfile.objects.select_related('user').filter(is_active=True)
        data = []
        for p in profiles:
            data.append({
                'id': p.user.id,
                'username': p.user.username,
                'company_name': p.company_name,
                'joined': p.user.date_joined,
            })
        return Response(data)


# ─── AVERTISSEMENTS ÉDITEURS (moderation réelle, propre à chaque compte) ─────

class AdminIssueWarningView(generics.CreateAPIView):
    """Un admin émet un avertissement réel et persistant à un éditeur précis.

    Contrairement à l'ancienne implémentation (état local Flutter uniquement),
    l'avertissement est enregistré en base et notifié à l'éditeur concerné,
    et lui seul — chaque compte éditeur ne voit que ses propres avertissements.
    """
    serializer_class = PosterWarningCreateSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def perform_create(self, serializer):
        warning = serializer.save(issued_by=self.request.user)
        try:
            from apps.notifications.views import send_notification
            send_notification(
                user=warning.publisher,
                type_notif='system',
                title='Avertissement reçu',
                message=warning.reason,
                data={'severity': warning.severity, 'warning_id': warning.id},
            )
        except Exception:
            logger.exception('Impossible d\'envoyer la notification d\'avertissement')


class AdminPosterWarningsListView(generics.ListAPIView):
    """Vue admin : historique des avertissements d'un éditeur donné."""
    serializer_class = PosterWarningSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def get_queryset(self):
        qs = PosterWarning.objects.select_related('publisher', 'issued_by')
        publisher_id = self.kwargs.get('pk') or self.request.query_params.get('publisher_id')
        if publisher_id:
            qs = qs.filter(publisher_id=publisher_id)
        return qs


class MyWarningsView(generics.ListAPIView):
    """Vue éditeur : ses propres avertissements uniquement (isolation stricte par compte)."""
    serializer_class = PosterWarningSerializer
    permission_classes = [permissions.IsAuthenticated, IsPublisher]

    def get_queryset(self):
        return PosterWarning.objects.filter(
            publisher=self.request.user
        ).select_related('issued_by')


# ─── RÉINITIALISATION DE MOT DE PASSE (flux réel par code à usage unique) ────

class PasswordResetRequestView(APIView):
    """Étape 1 : génère un code à 6 chiffres, valable 10 minutes, et l'envoie par email.

    Répond toujours avec succès, que l'email existe ou non, afin d'éviter
    toute énumération de comptes existants.
    """
    permission_classes = [permissions.AllowAny]
    throttle_scope = 'auth'
    throttle_classes = [ScopedRateThrottle]

    def post(self, request):
        serializer = PasswordResetRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data['email'].strip()

        user = User.objects.filter(email__iexact=email).first()
        if user:
            raw_code = PasswordResetCode.issue_for(user)
            try:
                send_mail(
                    subject='Digital Press — Code de réinitialisation',
                    message=(
                        f"Votre code de réinitialisation est : {raw_code}\n"
                        f"Il expire dans 10 minutes. Si vous n'êtes pas à l'origine de "
                        f"cette demande, ignorez cet email."
                    ),
                    from_email=getattr(settings, 'DEFAULT_FROM_EMAIL', 'no-reply@digitalpress.local'),
                    recipient_list=[email],
                    fail_silently=True,
                )
            except Exception:
                logger.exception('Échec envoi email de réinitialisation')

        return Response({
            'message': "Si un compte existe avec cet email, un code de vérification vient d'être envoyé."
        })


class PasswordResetVerifyView(APIView):
    """Étape 2 : vérifie le code sans encore modifier le mot de passe."""
    permission_classes = [permissions.AllowAny]
    throttle_scope = 'auth'
    throttle_classes = [ScopedRateThrottle]

    def post(self, request):
        serializer = PasswordResetVerifySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data['email'].strip()
        code = serializer.validated_data['code'].strip()

        user = User.objects.filter(email__iexact=email).first()
        generic_error = {'code': "Code invalide ou expiré."}
        if not user:
            return Response(generic_error, status=status.HTTP_400_BAD_REQUEST)

        reset_code = PasswordResetCode.objects.filter(
            user=user, is_used=False
        ).order_by('-created_at').first()
        if not reset_code or not reset_code.is_valid():
            return Response(generic_error, status=status.HTTP_400_BAD_REQUEST)

        if reset_code.code_hash != PasswordResetCode.hash_code(code):
            reset_code.attempts += 1
            reset_code.save(update_fields=['attempts'])
            return Response(generic_error, status=status.HTTP_400_BAD_REQUEST)

        return Response({'message': 'Code valide.'})


class PasswordResetConfirmView(APIView):
    """Étape 3 : vérifie le code une dernière fois et applique le nouveau mot de passe."""
    permission_classes = [permissions.AllowAny]
    throttle_scope = 'auth'
    throttle_classes = [ScopedRateThrottle]

    def post(self, request):
        serializer = PasswordResetConfirmSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data['email'].strip()
        code = serializer.validated_data['code'].strip()
        new_password = serializer.validated_data['new_password']

        user = User.objects.filter(email__iexact=email).first()
        generic_error = {'code': "Code invalide ou expiré."}
        if not user:
            return Response(generic_error, status=status.HTTP_400_BAD_REQUEST)

        reset_code = PasswordResetCode.objects.filter(
            user=user, is_used=False
        ).order_by('-created_at').first()
        if not reset_code or not reset_code.is_valid():
            return Response(generic_error, status=status.HTTP_400_BAD_REQUEST)

        if reset_code.code_hash != PasswordResetCode.hash_code(code):
            reset_code.attempts += 1
            reset_code.save(update_fields=['attempts'])
            return Response(generic_error, status=status.HTTP_400_BAD_REQUEST)

        user.set_password(new_password)
        user.save(update_fields=['password'])
        reset_code.is_used = True
        reset_code.save(update_fields=['is_used'])
        # Invalide tous les autres codes en attente pour ce compte.
        PasswordResetCode.objects.filter(user=user, is_used=False).update(is_used=True)

        return Response({'message': 'Mot de passe réinitialisé avec succès.'})


# ─── ÉTAPE 1/3 & 2/3 : VÉRIFICATION D'ÉDITEUR ────────────────────────────

class MyPublisherVerificationView(APIView):
    """GET : statut actuel de ma vérification (ou null si jamais soumise).
    POST : soumettre (ou re-soumettre après rejet) le formulaire."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        try:
            verification = request.user.verification
        except PublisherVerification.DoesNotExist:
            return Response({'verification': None})
        return Response({'verification': PublisherVerificationSerializer(verification).data})

    def post(self, request):
        existing = getattr(request.user, 'verification', None)
        if existing and existing.status == 'approved':
            return Response(
                {'error': 'Votre compte est déjà vérifié.'}, status=status.HTTP_400_BAD_REQUEST
            )
        serializer = PublisherVerificationSubmitSerializer(
            data=request.data, context={'request': request}
        )
        serializer.is_valid(raise_exception=True)
        verification = serializer.save()

        # Si l'utilisateur était 'reader', passer au rôle 'publisher'
        if request.user.role == 'reader':
            request.user.role = 'publisher'
            request.user.save(update_fields=['role'])

        PublisherProfile.objects.get_or_create(
            user=request.user,
            defaults={'company_name': verification.legal_company_name or request.user.name or request.user.username}
        )

        Notification.objects.create(
            user=request.user,
            type_notif='verification_submitted',
            title='Vérification envoyée',
            message="Votre dossier a été transmis à l'administrateur. Vous recevrez une "
                    "réponse sous 24h par notification et par email.",
        )
        # ─── CORRECTIF : l'admin doit être prévenu de façon DURABLE ────────
        # push_to_admins() ci-dessous n'est qu'un signal temps réel éphémère
        # (raté si aucun admin n'est connecté à cet instant précis). Sans
        # une vraie Notification en base, un admin qui se connecte plus
        # tard ne verrait jamais qu'un dossier attend sa validation.
        for admin_user in User.objects.filter(role='admin', is_active=True):
            Notification.objects.create(
                user=admin_user,
                type_notif='verification_submitted',
                title='Nouvelle vérification éditeur',
                message=f"{verification.legal_company_name} a soumis un dossier de vérification à traiter.",
            )
        from apps.notifications.realtime import push_to_admins
        push_to_admins('admin_stats_changed', {'reason': 'new_verification'})
        return Response(
            PublisherVerificationSerializer(verification).data, status=status.HTTP_201_CREATED
        )


class AdminPublisherVerificationListView(generics.ListAPIView):
    """Liste des dossiers de vérification pour l'admin (filtrable par statut)."""
    serializer_class = PublisherVerificationSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def get_queryset(self):
        qs = PublisherVerification.objects.select_related('user').all()
        status_filter = self.request.query_params.get('status')
        if status_filter:
            qs = qs.filter(status=status_filter)
        return qs.order_by('status', '-submitted_at')


class AdminPublisherVerificationReviewView(APIView):
    """POST : l'admin approuve ou rejette un dossier de vérification.
    Déclenche notification in-app + email dans les deux cas (l'éditeur doit
    savoir que sa vérification a été confirmée OU refusée, avec le motif)."""
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def post(self, request, pk):
        try:
            verification = PublisherVerification.objects.select_related('user').get(pk=pk)
        except PublisherVerification.DoesNotExist:
            return Response({'error': 'Dossier introuvable.'}, status=404)

        serializer = PublisherVerificationReviewSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        decision = serializer.validated_data['decision']
        reason = serializer.validated_data.get('rejection_reason', '')

        verification.status = decision
        verification.rejection_reason = reason if decision == 'rejected' else ''
        verification.reviewed_at = timezone.now()
        verification.reviewed_by = request.user
        verification.save(update_fields=[
            'status', 'rejection_reason', 'reviewed_at', 'reviewed_by', 'updated_at'
        ])

        publisher = verification.user
        if decision == 'approved':
            publisher.role = 'publisher'
            publisher.is_verified = True
            publisher.save(update_fields=['role', 'is_verified'])
            PublisherProfile.objects.get_or_create(
                user=publisher,
                defaults={'company_name': verification.legal_company_name or publisher.name or publisher.username}
            )
            title = 'Vérification confirmée !'
            message = ("Votre dossier a été validé. Vous pouvez commencer à publier dès "
                       "maintenant, gratuitement — aucun abonnement à choisir.")
            email_subject = 'DigitalPress — Votre compte éditeur est vérifié'
            email_body = (
                f"Bonjour {publisher.name or publisher.username},\n\n"
                "Bonne nouvelle : votre dossier de vérification a été validé par notre équipe.\n"
                "Connectez-vous à l'application pour commencer à publier — c'est gratuit et "
                "automatique, votre palier évoluera ensuite selon votre activité.\n\n"
                "L'équipe DigitalPress"
            )
        else:
            title = 'Vérification refusée'
            message = f"Votre dossier a été refusé. Motif : {reason}. Vous pouvez corriger et le soumettre à nouveau."
            email_subject = 'DigitalPress — Votre dossier de vérification a été refusé'
            email_body = (
                f"Bonjour {publisher.name or publisher.username},\n\n"
                f"Votre dossier de vérification a été refusé pour le motif suivant :\n{reason}\n\n"
                "Vous pouvez corriger les informations et le soumettre à nouveau depuis "
                "l'application.\n\nL'équipe DigitalPress"
            )

        Notification.objects.create(
            user=publisher, type_notif='verification_reviewed', title=title, message=message,
        )

        if publisher.email:
            try:
                send_mail(
                    email_subject, email_body, settings.DEFAULT_FROM_EMAIL,
                    [publisher.email], fail_silently=True,
                )
            except Exception:
                logger.exception("Echec envoi email de vérification à %s", publisher.email)

        return Response(PublisherVerificationSerializer(verification).data)


class SocialLoginView(APIView):
    """Connexion ou inscription automatique via un compte social (Google / Facebook).
    Délivre directement une paire de tokens JWT (access & refresh) et l'objet user.

    ⚠️ FAILLE DE SÉCURITÉ CORRIGÉE : cette vue faisait confiance à l'email
    envoyé par le CLIENT sans jamais vérifier qu'il en est bien le
    propriétaire — n'importe qui pouvait s'authentifier comme n'importe
    quel email en le déclarant simplement dans la requête (prise de
    contrôle de compte triviale). Remplacée par GoogleAuthView /
    FacebookAuthView ci-dessous, qui vérifient un vrai jeton Google/Facebook
    auprès de leurs serveurs. Cette vue reste seulement active en
    développement (DEBUG=True) pour ne pas casser un flux de test existant,
    jamais en production.
    """
    permission_classes = [permissions.AllowAny]
    throttle_scope = 'auth'
    throttle_classes = [ScopedRateThrottle]

    def post(self, request):
        if not settings.DEBUG:
            return Response(
                {'error': "Utilisez /auth/google/ ou /auth/facebook/ (vérification de jeton réelle)."},
                status=status.HTTP_410_GONE,
            )
        serializer = SocialLoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        email = serializer.validated_data['email'].strip().lower()
        name = serializer.validated_data.get('name', '').strip()
        provider = serializer.validated_data['provider']

        username = email.split('@')[0] if '@' in email else email

        user = User.objects.filter(email__iexact=email).first()
        if not user:
            # Générer un nom d'utilisateur unique si besoin
            base_username = username
            counter = 1
            while User.objects.filter(username=base_username).exists():
                base_username = f"{username}{counter}"
                counter += 1

            user = User.objects.create_user(
                username=base_username,
                email=email,
                name=name or base_username,
                role='reader',
                is_active=True,
            )
            # Générer un mot de passe aléatoire sécurisé inexploitable
            user.set_unusable_password()
            user.save(update_fields=['password'])
        else:
            if name and not user.name:
                user.name = name
                user.save(update_fields=['name'])

        refresh = RefreshToken.for_user(user)
        return Response({
            'access': str(refresh.access_token),
            'refresh': str(refresh),
            'user': UserSerializer(user, context={'request': request}).data,
            'provider': provider,
        }, status=status.HTTP_200_OK)



# ─── CONNEXION GOOGLE RÉELLE ──────────────────────────────────────────────
class GoogleAuthView(APIView):
    """POST {'id_token': '<jeton d'identité Google>'} -> connecte ou crée
    automatiquement un compte Lecteur, puis renvoie les mêmes jetons JWT
    que la connexion classique.
    """
    permission_classes = [permissions.AllowAny]
    throttle_scope = 'auth'
    throttle_classes = [ScopedRateThrottle]

    def post(self, request):
        # ─── FAILLE DE SÉCURITÉ CORRIGÉE (audit 2026-08-16) ───────────────
        # L'ancien code décodait le jeton SANS VÉRIFIER SA SIGNATURE
        # (jwt.decode(..., verify_signature=False)) dès que le Client ID
        # Google n'était pas configuré : n'importe qui pouvait forger un
        # jeton déclarant l'email de sa victime et prendre le contrôle de
        # son compte. Un jeton n'est désormais accepté que s'il est
        # VÉRIFIÉ CRYPTOGRAPHIQUEMENT par Google (audience = notre Client
        # ID). Sans Client ID configuré, la connexion Google est
        # simplement indisponible (503) — jamais de fallback non vérifié.
        client_id = getattr(settings, 'GOOGLE_OAUTH_CLIENT_ID', '') or os.environ.get('GOOGLE_OAUTH_CLIENT_ID', '')
        if not client_id:
            return Response(
                {'error': 'La connexion Google n\'est pas configurée sur ce serveur (GOOGLE_OAUTH_CLIENT_ID manquant).'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        id_token_str = request.data.get('id_token')
        if not id_token_str:
            return Response({'error': 'id_token manquant.'}, status=400)

        idinfo = None
        try:
            from google.oauth2 import id_token as google_id_token
            from google.auth.transport import requests as google_requests

            idinfo = google_id_token.verify_oauth2_token(
                id_token_str, google_requests.Request(), client_id
            )
        except Exception as e:
            logger.warning(f"GoogleAuthView: vérification OAuth2 échouée: {e}")

        if not idinfo or not isinstance(idinfo, dict):
            return Response({'error': 'Jeton Google invalide ou expiré.'}, status=401)

        email = idinfo.get('email')
        if not email:
            return Response({'error': 'Email non disponible dans le jeton Google.'}, status=401)

        name = idinfo.get('name') or email.split('@')[0]
        avatar = idinfo.get('picture', '')

        user, created = User.objects.get_or_create(
            email=email,
            defaults={
                'username': email.split('@')[0] + '_' + get_random_string(5),
                'name': name,
                'avatar': avatar,
                'role': 'reader',  # Même règle que l'inscription classique :
                                   # jamais admin/éditeur via une voie publique.
                # ─── ACTIVATION PAR EMAIL OBLIGATOIRE (demande explicite) ─
                # Un compte créé via Google ne démarre plus vérifié d'office :
                # il doit valider son adresse email avec l'OTP reçu (15 min),
                # exactement comme un compte créé par inscription classique.
                'is_verified': False,
            },
        )
        if not user.is_active:
            return Response({'error': 'Ce compte est désactivé.'}, status=403)

        # ─── COMPTE NON ENCORE ACTIVÉ ─────────────────────────────────────
        # Nouveau compte OU compte existant jamais activé : aucun jeton n'est
        # délivré ; l'app bascule sur l'écran de saisie du code OTP. Un code
        # est émis/renvoyé à chaque tentative pour que l'utilisateur ne soit
        # jamais bloqué (un code expiré est remplacé par un nouveau).
        if not user.is_verified:
            _issue_and_send_activation_code(user)
            return Response({
                'email_verification_required': True,
                'email': email,
                'user': UserSerializer(user).data,
            })

        refresh = CustomTokenObtainPairSerializer.get_token(user)
        return Response({
            'access': str(refresh.access_token),
            'refresh': str(refresh),
            'user': UserSerializer(user).data,
        })


class FacebookAuthView(APIView):
    """POST {'access_token': '<jeton Facebook>'} -> même principe que
    GoogleAuthView, en vérifiant le jeton auprès du Graph API Facebook.

    Nécessite FACEBOOK_APP_ID + FACEBOOK_APP_SECRET configurés (voir .env).
    """
    permission_classes = [permissions.AllowAny]
    throttle_scope = 'auth'
    throttle_classes = [ScopedRateThrottle]

    def post(self, request):
        app_id = os.environ.get('FACEBOOK_APP_ID', '')
        app_secret = os.environ.get('FACEBOOK_APP_SECRET', '')
        if not app_id or not app_secret:
            return Response(
                {'error': "Connexion Facebook non configurée côté serveur."},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        access_token = request.data.get('access_token')
        if not access_token:
            return Response({'error': 'access_token manquant.'}, status=400)

        try:
            # Vérifie le jeton auprès de Facebook lui-même (jamais confiance
            # aveugle en un jeton fourni par le client).
            debug_resp = requests.get(
                'https://graph.facebook.com/debug_token',
                params={
                    'input_token': access_token,
                    'access_token': f'{app_id}|{app_secret}',
                },
                timeout=10,
            )
            debug_data = debug_resp.json().get('data', {})
            if not debug_data.get('is_valid') or debug_data.get('app_id') != app_id:
                return Response({'error': 'Jeton Facebook invalide.'}, status=401)

            profile_resp = requests.get(
                'https://graph.facebook.com/me',
                params={'fields': 'id,name,email,picture', 'access_token': access_token},
                timeout=10,
            )
            profile = profile_resp.json()
        except Exception:
            logger.exception("FacebookAuthView: erreur de vérification du jeton.")
            return Response({'error': 'Impossible de vérifier ce jeton Facebook.'}, status=502)

        email = profile.get('email')
        if not email:
            return Response(
                {'error': "Votre compte Facebook n'a pas d'email public associé."}, status=400
            )

        name = profile.get('name', '')
        avatar = (profile.get('picture') or {}).get('data', {}).get('url', '')

        user, created = User.objects.get_or_create(
            email=email,
            defaults={
                'username': email.split('@')[0] + '_' + get_random_string(5),
                'name': name,
                'avatar': avatar,
                'role': 'reader',
                # Activation par email obligatoire, comme pour Google (ci-dessus).
                'is_verified': False,
            },
        )
        if not user.is_active:
            return Response({'error': 'Ce compte est désactivé.'}, status=403)

        # Compte non encore activé : pas de jeton, bascule sur l'écran OTP.
        if not user.is_verified:
            _issue_and_send_activation_code(user)
            return Response({
                'email_verification_required': True,
                'email': email,
                'user': UserSerializer(user).data,
            })

        refresh = CustomTokenObtainPairSerializer.get_token(user)
        return Response({
            'access': str(refresh.access_token),
            'refresh': str(refresh),
            'user': UserSerializer(user).data,
        })
