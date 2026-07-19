from django.http import JsonResponse
from django.views.decorators.http import require_GET
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response


@api_view(['GET'])
@permission_classes([AllowAny])
def health_check(request):
    """Point de contrôle pour vérifier que l'API est en ligne."""
    return Response({
        'status': 'ok',
        'service': 'digital-press-api',
        'version': 'v1',
    })


@require_GET
def api_index(request):
    """Page d'accueil API — évite le 404 sur /api/."""
    return JsonResponse({
        'service': 'Digital Press API',
        'version': 'v1',
        'status': 'ok',
        'endpoints': {
            'health': '/api/health/',
            'accounts': '/api/accounts/',
            'login': '/api/accounts/login/',
            'register': '/api/accounts/register/',
            'publications': '/api/publications/',
            'abonnements': '/api/abonnements/',
            'paiements': '/api/paiements/',
            'notifications': '/api/notifications/',
            'admin': '/admin/',
        },
        'flutter_base_url': 'http://127.0.0.1:8000/api/',
        'android_emulator_base_url': 'http://10.0.2.2:8000/api/',
    })


@require_GET
def root_index(request):
    """Page d'accueil racine — évite le 404 sur /."""
    return JsonResponse({
        'message': 'Digital Press Backend',
        'api': '/api/',
        'health': '/api/health/',
        'admin': '/admin/',
    })
