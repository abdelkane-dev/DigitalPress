from rest_framework import generics, permissions
from .models import FeatureItem
from .serializers import FeatureItemSerializer, FeatureItemStatusUpdateSerializer
from apps.accounts.permissions import IsAdmin, IsAdminOrPublisher


class FeatureItemListCreateView(generics.ListCreateAPIView):
    """GET  : liste des fonctionnalités visibles pour le rôle de l'utilisateur
              (les siennes + celles scope='both' + celles de son propre rôle).
    POST : Admin et Éditeur peuvent tous les deux proposer une nouvelle
           fonctionnalité pas encore implémentée.
    """
    serializer_class = FeatureItemSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdminOrPublisher]

    def get_queryset(self):
        user = self.request.user
        role_scope = 'admin' if user.role == 'admin' else 'publisher'
        qs = FeatureItem.objects.filter(scope__in=[role_scope, 'both'])
        status_filter = self.request.query_params.get('status')
        if status_filter:
            qs = qs.filter(status=status_filter)
        return qs

    def perform_create(self, serializer):
        # Par défaut, une suggestion créée par un Éditeur ne concerne que les
        # éditeurs ; une suggestion admin est visible par tous, sauf si un
        # scope explicite est fourni.
        default_scope = 'both' if self.request.user.role == 'admin' else 'publisher'
        serializer.save(
            created_by=self.request.user,
            scope=self.request.data.get('scope', default_scope),
        )


class FeatureItemStatusUpdateView(generics.UpdateAPIView):
    """PATCH /api/roadmap/<pk>/status/ — Admin seulement : fait évoluer le
    statut ("à venir" → "en cours" → "fait"/"non retenu")."""
    queryset = FeatureItem.objects.all()
    serializer_class = FeatureItemStatusUpdateSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdmin]


class FeatureItemDeleteView(generics.DestroyAPIView):
    """DELETE /api/roadmap/<pk>/ — Admin seulement."""
    queryset = FeatureItem.objects.all()
    serializer_class = FeatureItemSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdmin]
