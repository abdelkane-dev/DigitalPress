from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import PublicationViewSet, ReaderPublicationViewSet

router = DefaultRouter()
# Route éditeur pour gérer ses propres publications 
router.register(r'manage', PublicationViewSet, basename='publication-manage')
# Route lecteur pour le catalogue global des publications disponibles à l'achat
router.register(r'catalog', ReaderPublicationViewSet, basename='publication-catalog')

urlpatterns = [
    path('', include(router.urls)),
]