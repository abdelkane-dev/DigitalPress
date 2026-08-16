"""
URL Configuration — Digital Press Backend
Routes principales:
  /api/accounts/       → Auth, profils, utilisateurs
  /api/publications/   → Publications, catégories, avis
  /api/abonnements/    → Plans et abonnements
  /api/paiements/      → Transactions Movapay, retraits
  /api/comptabilite/   → Journal, réconciliation, exports, dashboard
  /api/notifications/  → Notifications, tokens FCM
"""
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from core.health import health_check, api_index, root_index
from apps.paiements.views import DemanderRetraitView, MesDemandesRetraitView

from django.http import HttpResponse, HttpResponseRedirect

urlpatterns = [
    path('favicon.ico', lambda r: HttpResponse(status=204)),
    path('sw.js', lambda r: HttpResponse("// Service Worker placeholder", content_type="application/javascript", status=200)),
    path('notifications/api/', lambda r: HttpResponseRedirect('/api/notifications/')),
    path('', root_index, name='root'),
    path('api/', api_index, name='api-index'),
    path('admin/', admin.site.urls),
    path('api/health/', health_check, name='health-check'),
    path('api/accounts/', include('apps.accounts.urls')),
    path('api/publications/', include('apps.publications.urls')),
    path('api/abonnements/', include('apps.abonnements.urls')),
    path('api/paiements/', include('apps.paiements.urls')),
    path('api/entreprise/retrait/demander/', DemanderRetraitView.as_view(), name='legacy_demander_retrait'),
    path('api/entreprise/retrait/mes-demandes/', MesDemandesRetraitView.as_view(), name='legacy_mes_demandes_retrait'),
    path('api/', include('apps.comptabilite.urls')),
    path('api/notifications/', include('apps.notifications.urls')),
    path('api/roadmap/', include('apps.roadmap.urls')),
]

# Serve media files in development
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)