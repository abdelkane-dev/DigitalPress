import logging
from django.shortcuts import get_object_or_404

from rest_framework import generics, status, permissions
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenObtainPairView
from django.conf import settings
from django.contrib.auth import update_session_auth_hash
from django.core.mail import send_mail
from django.utils import timezone
from .models import User, PublisherProfile, PosterWarning, PasswordResetCode
from .serializers import (
    UserSerializer, RegisterSerializer,
    CustomTokenObtainPairSerializer, ChangePasswordSerializer,
    PublisherProfileSerializer, PublicPublisherProfileSerializer,
    PosterWarningSerializer, PosterWarningCreateSerializer,
    PasswordResetRequestSerializer, PasswordResetVerifySerializer,
    PasswordResetConfirmSerializer,
)
from .permissions import IsAdmin, IsPublisher

logger = logging.getLogger('apps')


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
        return Response(
            UserSerializer(user).data,
            status=status.HTTP_201_CREATED
        )


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
                'commission_rate': str(p.commission_rate),
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
