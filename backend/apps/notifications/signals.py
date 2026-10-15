"""Diffuse chaque nouvelle Notification en temps réel par WebSocket.

Centralisé ici via un signal post_save plutôt qu'ajouté à chaque site
d'appel de `Notification.objects.create(...)` (il y en a des dizaines,
dispersés dans accounts/paiements/publications/comptabilite) : ainsi,
TOUTE notification créée n'importe où dans le backend est automatiquement
poussée en direct, sans risque d'en oublier une nouvelle à l'avenir.
"""
import logging

from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import Notification

logger = logging.getLogger('apps')


@receiver(post_save, sender=Notification)
def broadcast_notification(sender, instance, created, **kwargs):
    if not created:
        return

    try:
        from asgiref.sync import async_to_sync
        from channels.layers import get_channel_layer

        channel_layer = get_channel_layer()
        if channel_layer is None:
            return

        async_to_sync(channel_layer.group_send)(
            f'user_{instance.user_id}',
            {
                'type': 'notify',
                'payload': {
                    'id': instance.id,
                    'type_notif': instance.type_notif,
                    'type_notif_display': instance.get_type_notif_display(),
                    'title': instance.title,
                    'message': instance.message,
                    'is_read': instance.is_read,
                    'data': instance.data if isinstance(instance.data, dict) else {},
                    'created_at': instance.created_at.isoformat(),
                },
            },
        )
    except Exception:
        # Le temps réel est un confort, jamais un point de défaillance
        # critique : si Channels/Redis est indisponible, la notification
        # reste créée en base normalement (le polling de secours côté app
        # la récupérera quand même, juste avec un peu de latence).
        logger.exception("Echec de diffusion WebSocket pour notification %s", instance.id)

    # ─── PUSH FCM (notification système, même app fermée) ───────────────
    # Centralisé ici, comme la diffusion WebSocket : TOUTE notification
    # créée n'importe où dans le backend (paiement, vérification, retrait,
    # commentaire...) déclenche désormais un push Firebase, que le code
    # d'origine ait appelé send_notification() ou Notification.objects
    # .create() directement. L'envoi est silencieux tant que le compte de
    # service Firebase n'est pas configuré (FIREBASE_SERVICE_ACCOUNT_JSON
    # ou _PATH dans le .env) — voir send_fcm_push().
    try:
        from .views import send_fcm_push
        push_data = dict(instance.data) if isinstance(instance.data, dict) else {}
        # Le push emporte l'id de l'article (si connu) : le tap sur la
        # notification système ouvre directement l'article concerné.
        pub_id = push_data.get('publication_id')
        if pub_id and 'article_id' not in push_data:
            push_data['article_id'] = pub_id
        send_fcm_push(instance.user, instance.title, instance.message, push_data)
    except Exception:
        # Un échec de push ne doit jamais casser la création de la
        # notification elle-même.
        logger.exception("Echec d'envoi FCM pour notification %s", instance.id)
