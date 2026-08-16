import os

from django.core.asgi import get_asgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

# get_asgi_application() DOIT être appelé avant d'importer quoi que ce soit
# qui touche aux modèles Django (ex: nos consumers/routing) — sinon
# AppRegistryNotReady. C'est pourquoi l'import de channels/routing est fait
# après cette ligne, malgré ce que suggérerait l'ordre "naturel".
django_asgi_app = get_asgi_application()

from channels.routing import ProtocolTypeRouter, URLRouter  # noqa: E402
from channels.security.websocket import AllowedHostsOriginValidator  # noqa: E402

import apps.notifications.routing  # noqa: E402
import apps.publications.routing  # noqa: E402
from apps.notifications.jwt_auth_middleware import JWTAuthMiddleware  # noqa: E402

application = ProtocolTypeRouter({
    'http': django_asgi_app,
    # Les WebSockets utilisent leur propre authentification (JWT passé en
    # query param, voir jwt_auth_middleware.py) car les navigateurs/clients
    # WebSocket ne peuvent pas envoyer d'en-tête Authorization personnalisé
    # à l'ouverture de la connexion.
    'websocket': AllowedHostsOriginValidator(
        JWTAuthMiddleware(
            URLRouter(
                apps.notifications.routing.websocket_urlpatterns
                + apps.publications.routing.websocket_urlpatterns
            )
        )
    ),
})
