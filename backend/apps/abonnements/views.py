from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.utils import timezone
from datetime import timedelta
from .models import Plan, Abonnement
from .serializers import (
    PlanSerializer, AbonnementSerializer, AbonnementCreateSerializer,
    PublisherPlanCreateSerializer,
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
        serializer.save(publisher=self.request.user)


class PublisherPlanDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Détail / modification / suppression d'un plan éditeur."""
    permission_classes = [permissions.IsAuthenticated, IsPublisher]
    serializer_class = PublisherPlanCreateSerializer

    def get_queryset(self):
        return Plan.objects.filter(publisher=self.request.user)
