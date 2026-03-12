from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)

urlpatterns = [
    # Interface d'administration Django (pour valider les KYC et gérer les litiges)
    path('admin/', admin.site.urls),

    # --- AUTHENTIFICATION (JWT) ---
    # Endpoint pour se connecter et recevoir le Token (Access & Refresh)
    path('api/auth/login/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    # Endpoint pour rafraîchir le token sans se reconnecter
    path('api/auth/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    # Inscription et gestion du profil (apps/users)
    path('api/auth/', include('apps.users.urls')),

    # --- MODULE PUBLICATIONS ---
    # Gestion du catalogue pour les lecteurs et upload pour les éditeurs
    path('api/publications/', include('apps.publications.urls')),

    # --- MODULE ABONNEMENTS ---
    # Consultation des abonnements actifs et historique pour le lecteur
    path('api/subscriptions/', include('apps.subscriptions.urls')),

    # --- MODULE PAIEMENTS ---
    # Tunnel d'achat (Stripe, Mobile Money) et facturation
    path('api/payments/', include('apps.payments.urls')),

]

# Configuration pour servir les fichiers médias (images de couverture, PDFs) 
# UNIQUEMENT en mode développement. En production, utilisez un serveur de fichiers sécurisé.
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)




