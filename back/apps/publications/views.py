from rest_framework import generics, permissions
from .models import Publication
from .serializers import PublicationSerializer
from apps.accounts.permissions import IsPublisher

class PublicationListView(generics.ListAPIView):
    queryset = Publication.objects.all().order_by('-created_at')
    serializer_class = PublicationSerializer
    permission_classes = (permissions.AllowAny,)

class PublicationDetailView(generics.RetrieveAPIView):
    queryset = Publication.objects.all()
    serializer_class = PublicationSerializer
    permission_classes = (permissions.AllowAny,)

class PublisherPublicationsView(generics.ListAPIView):
    serializer_class = PublicationSerializer

    def get_queryset(self):
        user = self.request.user
        return Publication.objects.filter(publisher=user)

class PublicationCreateView(generics.CreateAPIView):
    serializer_class = PublicationSerializer
    permission_classes = (permissions.IsAuthenticated, IsPublisher)

    def perform_create(self, serializer):
        serializer.save(publisher=self.request.user)
