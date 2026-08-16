from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.utils import timezone
from datetime import timedelta
from .models import Plan, Abonnement, PlatformPlan, PublisherSubscription
from .serializers import (
    PlanSerializer, AbonnementSerializer, AbonnementCreateSerializer,
    PublisherPlanCreateSerializer, PlatformPlanSerializer,
    PublisherSubscriptionSerializer,
)
from apps.accounts.permissions import IsAdmin, IsReader, IsPublisher


class PlanListView(generics.ListAPIView):
    serializer_class = PlanSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        qs = Plan.objects.filter(is_active=True)
        pub_id = self.request.query_params.get('publisher_id')
        if pub_id:
            qs = qs.filter(publisher_id=pub_id)
        return qs


class PlanAdminView(generics.ListCreateAPIView):
    queryset = Plan.objects.all()
    serializer_class = PlanSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdmin]


class PlanDetailAdminView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Plan.objects.all()
    serializer_class = PlanSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdmin]


class MyAbonnementsView(generics.ListAPIView):
    serializer_class = AbonnementSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Abonnement.objects.filter(
            reader=self.request.user
        ).select_related('publication', 'plan', 'publisher').order_by('-created_at')


class AbonnementCreateView(generics.CreateAPIView):
    serializer_class = AbonnementCreateSerializer
    permission_classes = [permissions.IsAuthenticated]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        abonnement = serializer.save()
        return Response(
            AbonnementSerializer(abonnement).data,
            status=status.HTTP_201_CREATED
        )


class AbonnementActivateView(APIView):
    """Activé après confirmation de paiement Movapay."""
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def post(self, request, pk):
        try:
            ab = Abonnement.objects.get(pk=pk)
        except Abonnement.DoesNotExist:
            return Response({'error': 'Abonnement introuvable.'}, status=404)

        period_days = {'monthly': 30, 'quarterly': 90, 'yearly': 365}
        days = period_days.get(ab.plan.period if ab.plan else 'monthly', 30)

        ab.status = 'active'
        ab.start_date = timezone.now()
        ab.end_date = timezone.now() + timedelta(days=days)
        ab.save()
        return Response(AbonnementSerializer(ab).data)


class AdminAbonnementsView(generics.ListAPIView):
    serializer_class = AbonnementSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def get_queryset(self):
        qs = Abonnement.objects.all().select_related('reader', 'publication', 'plan', 'publisher')
        status_filter = self.request.query_params.get('status')
        if status_filter:
            qs = qs.filter(status=status_filter)
        return qs.order_by('-created_at')


class PublisherAbonnementsView(generics.ListAPIView):
    """Abonnements reçus par un éditeur."""
    serializer_class = AbonnementSerializer
    permission_classes = [permissions.IsAuthenticated, IsPublisher]

    def get_queryset(self):
        return Abonnement.objects.filter(
            publisher=self.request.user, status='active'
        ).select_related('reader', 'publication').order_by('-created_at')


class PublisherPlansView(generics.ListCreateAPIView):
    """Permet à un éditeur de créer et gérer ses propres plans d'abonnement."""
    permission_classes = [permissions.IsAuthenticated, IsPublisher]

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return PublisherPlanCreateSerializer
        return PlanSerializer

    def get_queryset(self):
        return Plan.objects.filter(publisher=self.request.user)

    def perform_create(self, serializer):
        # ─── AVANTAGE RÉEL DU PLAN : NOMBRE D'OFFRES LECTEUR ───────────────
        # Le plan plateforme actif fixe combien d'offres d'abonnement
        # (Lecteur→Éditeur) cet éditeur peut créer — un vrai avantage
        # différent par plan (0 = illimité, ex : Premium).
        active_sub = self.request.user.platform_subscriptions.filter(
            status='active'
        ).select_related('plan').first()
        max_plans = active_sub.plan.max_reader_plans if (active_sub and active_sub.plan) else 3
        if max_plans > 0:
            current_count = Plan.objects.filter(publisher=self.request.user).count()
            if current_count >= max_plans:
                from rest_framework.exceptions import PermissionDenied
                raise PermissionDenied(
                    f"Votre plan plateforme permet de créer {max_plans} offre(s) d'abonnement "
                    f"maximum. Passez à un plan supérieur pour en créer davantage."
                )
        serializer.save(publisher=self.request.user)


class PublisherPlanDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Détail / modification / suppression d'un plan éditeur."""
    permission_classes = [permissions.IsAuthenticated, IsPublisher]
    serializer_class = PublisherPlanCreateSerializer

    def get_queryset(self):
        return Plan.objects.filter(publisher=self.request.user)


# ─── ABONNEMENT PLATEFORME (ÉDITEUR → PLATEFORME) ────────────────────────

class PlatformPlanListView(generics.ListAPIView):
    """Plans que l'admin propose aux éditeurs. Visible publiquement (AllowAny)."""
    serializer_class = PlatformPlanSerializer
    permission_classes = [permissions.AllowAny]
    queryset = PlatformPlan.objects.filter(is_active=True)


class PlatformPlanAdminView(generics.ListCreateAPIView):
    queryset = PlatformPlan.objects.all()
    serializer_class = PlatformPlanSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdmin]


class PlatformPlanAdminDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = PlatformPlan.objects.all()
    serializer_class = PlatformPlanSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdmin]


class MyPublisherSubscriptionView(APIView):
    """GET : palier plateforme actuel de l'éditeur connecté (automatique,
    sans paiement) + sa progression vers le palier suivant."""
    permission_classes = [permissions.IsAuthenticated, IsPublisher]

    def get(self, request):
        from .services import _compter_abonnes, _compter_publications, _compter_ventes, sync_publisher_tier
        sync_publisher_tier(request.user)
        sub = PublisherSubscription.objects.filter(
            publisher=request.user, status='active'
        ).order_by('-created_at').first()
        next_plan = PlatformPlan.objects.filter(
            is_active=True, min_subscribers__gt=(sub.plan.min_subscribers if sub and sub.plan else 0)
        ).order_by('min_subscribers').first()
        return Response({
            'subscription': PublisherSubscriptionSerializer(sub).data if sub else None,
            'has_access': getattr(request.user.publisher_profile, 'is_active', False)
            if hasattr(request.user, 'publisher_profile') else False,
            'progression': {
                'abonnes': _compter_abonnes(request.user),
                'publications': _compter_publications(request.user),
                'ventes': _compter_ventes(request.user),
                'palier_suivant': PlatformPlanSerializer(next_plan).data if next_plan else None,
            },
        })


class PublisherSubscribeView(APIView):
    """Conservé pour compatibilité d'URL uniquement : le palier plateforme
    est désormais 100% automatique (voir apps.abonnements.services), aucun
    paiement ni choix manuel n'est plus possible."""
    permission_classes = [permissions.IsAuthenticated, IsPublisher]

    def post(self, request, *args, **kwargs):
        return Response(
            {'error': "Le palier plateforme est automatique et gratuit : il évolue selon "
                      "votre nombre d'abonnés, de publications et de ventes. Aucune action "
                      "n'est nécessaire de votre part."},
            status=status.HTTP_400_BAD_REQUEST,
        )


class PublisherSubscriberManageView(APIView):
    """Gestion des abonnés par l'éditeur (page « Mes abonnés »).

    POST /api/abonnements/publisher/<pk>/cancel/  → retire l'abonné
      (annule SES abonnements chez cet éditeur).
    POST /api/abonnements/publisher/<pk>/ban/     → bannit le lecteur
      (annule les abonnements PUIS désactive son compte lecteur).

    Un éditeur ne peut agir que sur les abonnements de SES offres — jamais
    sur ceux d'un autre éditeur (et jamais sur un compte admin/éditeur).
    """
    permission_classes = [permissions.IsAuthenticated, IsPublisher]

    def post(self, request, pk, action):
        from django.contrib.auth import get_user_model
        User = get_user_model()

        if action not in ('cancel', 'ban'):
            return Response({'error': 'Action invalide (cancel ou ban).'}, status=400)

        subscriber = User.objects.filter(pk=pk).first()
        if subscriber is None:
            return Response({'error': 'Abonné introuvable.'}, status=404)

        # Un éditeur ne peut pas gérer un autre éditeur ni un admin.
        if subscriber.role != 'reader':
            return Response(
                {'error': "Seuls les comptes lecteur peuvent être gérés ici."},
                status=400,
            )

        # Annuler TOUS les abonnements actifs de ce lecteur chez cet éditeur.
        updated = Abonnement.objects.filter(
            publisher=request.user,
            reader=subscriber,
            status='active',
        ).update(status='cancelled')

        if action == 'ban':
            subscriber.is_active = False
            subscriber.save(update_fields=['is_active'])
            try:
                from apps.notifications.views import send_notification
                send_notification(
                    user=subscriber,
                    type_notif='system',
                    title='Compte suspendu par un éditeur',
                    message=(
                        f'Votre abonnement chez « '
                        f'{request.user.publisher_profile.company_name or request.user.username} » '
                        f'a été annulé et votre compte lecteur suspendu.'
                    ),
                )
            except Exception:
                pass
            return Response({
                'detail': 'Abonné banni : abonnements annulés et compte suspendu.',
                'cancelled': updated,
                'banned': True,
            })

        return Response({
            'detail': 'Abonné retiré : ses abonnements ont été annulés.',
            'cancelled': updated,
            'banned': False,
        })


class AdminPublisherSubscriptionsView(generics.ListAPIView):
    """Vue admin : suivi de tous les abonnements plateforme des éditeurs."""
    serializer_class = PublisherSubscriptionSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def get_queryset(self):
        qs = PublisherSubscription.objects.all().select_related('publisher', 'plan')
        status_filter = self.request.query_params.get('status')
        if status_filter:
            qs = qs.filter(status=status_filter)
        return qs.order_by('-created_at')
