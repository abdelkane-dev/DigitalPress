"""Utilitaire générique de diffusion temps réel — réutilisable par
N'IMPORTE QUELLE app du backend (pas seulement notifications/publications),
sans dépendre du modèle Notification. Un seul WebSocket par utilisateur
(déjà ouvert pour les notifications) sert de bus d'événements partagé pour
tout le reste de la plateforme (favoris, statistiques, etc.) — évite de
multiplier les connexions WebSocket côté app.
"""
import logging

logger = logging.getLogger('apps')


def push_to_user(user_id, event, payload=None):
    """Pousse un événement léger (pas persisté en base) au canal WebSocket
    personnel de cet utilisateur. `event` identifie le type côté Flutter
    (ex: 'favorites_updated', 'stats_changed'), `payload` transporte les
    données utiles (optionnel — souvent le client se contente de recharger
    la vue concernée plutôt que d'attendre un payload complet)."""
    try:
        from asgiref.sync import async_to_sync
        from channels.layers import get_channel_layer

        channel_layer = get_channel_layer()
        if channel_layer is None:
            return
        async_to_sync(channel_layer.group_send)(
            f'user_{user_id}',
            {'type': 'notify', 'payload': {'event': event, **(payload or {})}},
        )
    except Exception:
        logger.exception("Echec push_to_user (event=%s, user=%s)", event, user_id)


def push_to_admins_and_publishers(event, payload=None):
    """Pousse un événement à tous les Admins ET Éditeurs connectés — jamais
    aux Lecteurs. Utilisé pour la roadmap fonctionnalités (apps.roadmap),
    qui n'existe que pour ces deux rôles : séparation stricte des accès par
    rôle, y compris au niveau des canaux WebSocket eux-mêmes (un Lecteur ne
    rejoint jamais ce canal, voir notifications/consumers.py)."""
    try:
        from asgiref.sync import async_to_sync
        from channels.layers import get_channel_layer

        channel_layer = get_channel_layer()
        if channel_layer is None:
            return
        async_to_sync(channel_layer.group_send)(
            'admins_and_publishers',
            {'type': 'notify', 'payload': {'event': event, **(payload or {})}},
        )
    except Exception:
        logger.exception("Echec push_to_admins_and_publishers (event=%s)", event)


def push_to_admins(event, payload=None):
    """Pousse un événement à TOUS les administrateurs connectés en même
    temps (groupe 'admins', rejoint automatiquement par tout utilisateur
    role=admin à la connexion — voir notifications/consumers.py)."""
    try:
        from asgiref.sync import async_to_sync
        from channels.layers import get_channel_layer

        channel_layer = get_channel_layer()
        if channel_layer is None:
            return
        async_to_sync(channel_layer.group_send)(
            'admins',
            {'type': 'notify', 'payload': {'event': event, **(payload or {})}},
        )
    except Exception:
        logger.exception("Echec push_to_admins (event=%s)", event)
