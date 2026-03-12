from rest_framework import viewsets, permissions, status
from rest_framework.response import Response
from rest_framework.decorators import action
from django.http import FileResponse
from .models import Publication, PublicationContent
from .serializers import PublicationSerializer # À créer sur le modèle du précédent message
from apps.subscriptions.models import Subscription
from django.http import FileResponse
from rest_framework.decorators import action

class PublicationViewSet(viewsets.ModelViewSet):
    queryset = Publication.objects.filter(status='published')
    serializer_class = PublicationSerializer

    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [permissions.IsAuthenticated()] # Devrait être IsPublisher
        return [permissions.AllowAny()]

    def perform_create(self, serializer):
        # Uniquement si KYC approuvé [cite: 39, 57]
        if self.request.user.kyc_status != 'approved':
            raise serializer.ValidationError("Votre compte éditeur n'est pas encore validé.")
        serializer.save(editor=self.request.user)

    @action(detail=True, methods=['get'], permission_classes=[permissions.IsAuthenticated])
    def read(self, request, pk=None):
        """
        Système de lecture sécurisée (DRM)[cite: 16, 101]. 
        Vérifie l'abonnement avant de servir le fichier.
        """
        pub = self.get_object()
        user = request.user

        # Vérification si l'utilisateur a un abonnement actif [cite: 46, 92]
        has_sub = Subscription.objects.filter(user=user, status='active').exists()
        
        if not has_sub and pub.price > 0:
            return Response({"error": "Abonnement requis pour lire ce contenu"}, status=403)

        content = pub.content
        # On renvoie le fichier directement sans exposer d'URL statique [cite: 108]
        return FileResponse(content.file, content_type='application/pdf')
    



class ReaderPublicationViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Publication.objects.filter(status='published')
    serializer_class = PublicationSerializer

    @action(detail=True, methods=['get'])
    def stream_content(self, request, pk=None):
        publication = self.get_object()
        user = request.user
        
        # Vérification de l'abonnement actif [cite: 45, 101]
        has_access = Subscription.objects.filter(
            user=user, 
            status='active', 
            end_date__gte=timezone.now()
        ).exists()

        if has_access:
            content = publication.content
            # On retourne le fichier de manière sécurisée
            return FileResponse(content.file, content_type='application/pdf')
        
        return Response({"detail": "Abonnement requis"}, status=403)