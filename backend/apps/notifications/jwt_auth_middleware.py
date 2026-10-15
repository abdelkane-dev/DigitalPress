"""Authentification JWT pour les connexions WebSocket.

Un navigateur/client WebSocket ne peut pas envoyer d'en-tête Authorization
personnalisé lors du handshake d'ouverture — le token JWT est donc passé en
paramètre de requête (?token=...), comme c'est l'usage standard pour les
WebSockets authentifiés. On réutilise exactement la même validation JWT que
le reste de l'API (SimpleJWT), donc les mêmes règles de sécurité
s'appliquent (expiration, blacklist après déconnexion, etc.).
"""
from urllib.parse import parse_qs

from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from rest_framework_simplejwt.tokens import AccessToken


@database_sync_to_async
def get_user_from_token(token):
    from apps.accounts.models import User
    try:
        validated_token = AccessToken(token)
        user_id = validated_token['user_id']
        user = User.objects.get(id=user_id, is_active=True)
        return user
    except (InvalidToken, TokenError, User.DoesNotExist, KeyError):
        return AnonymousUser()


class JWTAuthMiddleware:
    """Middleware ASGI : lit ?token=<jwt> dans l'URL WebSocket et peuple
    scope['user'] en conséquence, exactement comme AuthenticationMiddleware
    le fait pour les requêtes HTTP classiques."""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        query_string = scope.get('query_string', b'').decode()
        query_params = parse_qs(query_string)
        token = query_params.get('token', [None])[0]

        if token:
            scope['user'] = await get_user_from_token(token)
        else:
            scope['user'] = AnonymousUser()

        return await self.app(scope, receive, send)
