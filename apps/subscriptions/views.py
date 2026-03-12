from rest_framework import viewsets, permissions, status
from rest_framework.response import Response
from rest_framework.decorators import action
from .models import Subscription
from .serializers import SubscriptionSerializer

class SubscriptionViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Vue pour que le lecteur gère ses abonnements.
    Conformément au CDCF : Historique et statut.
    """
    serializer_class = SubscriptionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Un utilisateur ne voit que SES abonnements
        return Subscription.objects.filter(user=self.request.user).order_by('-created_at')

    @action(detail=True, methods=['post'])
    def cancel(self, request, pk=None):
        """
        Permet la résiliation simple.
        """
        subscription = self.get_object()
        if subscription.status == 'active':
            subscription.status = 'cancelled'
            subscription.save()
            return Response({'status': 'Abonnement résilié avec succès'})
        return Response({'error': 'Cet abonnement ne peut pas être résilié'}, status=400)