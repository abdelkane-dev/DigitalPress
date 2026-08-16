"""Diffuse chaque nouveau Comment (message de conversation d'article) en
temps réel par WebSocket, sur le groupe de l'article concerné."""
import logging

from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import Comment, Favorite, Review, Publication

logger = logging.getLogger('apps')


@receiver(post_save, sender=Publication)
def check_tier_on_publication_status_change(sender, instance, created, **kwargs):
    """Une publication qui passe en 'published' peut faire progresser le
    palier de l'éditeur (voir apps.abonnements.services.sync_publisher_tier)
    — couvre aussi bien la création directe en 'published' (cas par défaut)
    que le passage ultérieur d'un brouillon à 'published', que l'ancien
    hook posé uniquement à la création (PublicationCreateView.perform_create)
    ne couvrait pas."""
    if instance.status != 'published':
        return
    try:
        from apps.abonnements.services import sync_publisher_tier
        sync_publisher_tier(instance.publisher)
    except Exception:
        logger.exception("Echec verification de palier pour publication %s", instance.id)


@receiver(post_save, sender=Comment)
def broadcast_comment(sender, instance, created, **kwargs):
    if not created:
        return

    try:
        from asgiref.sync import async_to_sync
        from channels.layers import get_channel_layer

        channel_layer = get_channel_layer()
        if channel_layer is None:
            return

        async_to_sync(channel_layer.group_send)(
            f'conversation_{instance.publication_id}',
            {
                'type': 'new_message',
                'payload': {
                    'id': instance.id,
                    'publication': instance.publication_id,
                    'author': instance.author_id,
                    'author_name': instance.author.name or instance.author.username,
                    'text': instance.text,
                    'parent': instance.parent_id,
                    'created_at': instance.created_at.isoformat(),
                    'updated_at': instance.updated_at.isoformat(),
                },
            },
        )
    except Exception:
        # Comme pour les notifications : le temps réel est un confort, pas
        # un point de défaillance critique. Le message reste créé en base
        # normalement même si la diffusion WebSocket échoue.
        logger.exception("Echec de diffusion WebSocket pour commentaire %s", instance.id)


@receiver(post_save, sender=Favorite)
def broadcast_favorite_added(sender, instance, created, **kwargs):
    """Synchronise les favoris en direct entre tous les appareils connectés
    du même lecteur (ex : favori ajouté sur le téléphone, mis à jour
    instantanément sur la tablette sans rafraîchir)."""
    if not created:
        return
    from apps.notifications.realtime import push_to_user
    push_to_user(instance.reader_id, 'favorites_updated', {'publication_id': instance.publication_id})


from django.db.models.signals import post_delete  # noqa: E402


@receiver(post_delete, sender=Favorite)
def broadcast_favorite_removed(sender, instance, **kwargs):
    from apps.notifications.realtime import push_to_user
    push_to_user(instance.reader_id, 'favorites_updated', {'publication_id': instance.publication_id})


@receiver(post_save, sender=Comment)
def broadcast_stats_on_new_comment(sender, instance, created, **kwargs):
    """Un nouveau commentaire fait bouger les statistiques de l'éditeur
    concerné (engagement) : on le prévient pour qu'il rafraîchisse son
    tableau de bord sans action manuelle."""
    if not created:
        return
    from apps.notifications.realtime import push_to_user
    try:
        publisher_id = instance.publication.publisher_id
        push_to_user(publisher_id, 'stats_changed', {'reason': 'new_comment'})
    except Exception:
        logger.exception("Echec notification stats (nouveau commentaire) pour %s", instance.id)


@receiver(post_save, sender=Review)
def broadcast_stats_on_new_review(sender, instance, created, **kwargs):
    """Une nouvelle note/avis fait bouger la moyenne affichée à l'éditeur
    (et potentiellement aux lecteurs qui regardent l'article) en direct."""
    from apps.notifications.realtime import push_to_user

    try:
        publisher_id = instance.publication.publisher_id
        push_to_user(publisher_id, 'stats_changed', {'reason': 'new_review'})
    except Exception:
        logger.exception("Echec notification stats (nouvel avis) pour %s", instance.id)

    # Aussi diffusé sur le salon de l'article : les lecteurs qui regardent
    # la fiche en ce moment voient la nouvelle moyenne sans recharger.
    try:
        from asgiref.sync import async_to_sync
        from channels.layers import get_channel_layer

        channel_layer = get_channel_layer()
        if channel_layer is not None:
            async_to_sync(channel_layer.group_send)(
                f'conversation_{instance.publication_id}',
                {'type': 'new_message', 'payload': {'event': 'review_updated'}},
            )
    except Exception:
        logger.exception("Echec diffusion WebSocket du nouvel avis pour %s", instance.id)


@receiver(post_save, sender=Comment)
def broadcast_stats_on_new_comment(sender, instance, created, **kwargs):
    """Un nouveau commentaire fait bouger les statistiques de l'éditeur
    concerné (engagement) : on le prévient pour qu'il rafraîchisse son
    tableau de bord sans action manuelle."""
    if not created:
        return
    from apps.notifications.realtime import push_to_user
    try:
        publisher_id = instance.publication.publisher_id
        push_to_user(publisher_id, 'stats_changed', {'reason': 'new_comment'})
    except Exception:
        logger.exception("Echec notification stats (nouveau commentaire) pour %s", instance.id)


@receiver(post_save, sender=Review)
def broadcast_stats_on_new_review(sender, instance, created, **kwargs):
    """Une nouvelle note/avis fait bouger la moyenne affichée à l'éditeur
    (et potentiellement aux lecteurs qui regardent l'article) en direct."""
    from apps.notifications.realtime import push_to_user

    try:
        publisher_id = instance.publication.publisher_id
        push_to_user(publisher_id, 'stats_changed', {'reason': 'new_review'})
    except Exception:
        logger.exception("Echec notification stats (nouvel avis) pour %s", instance.id)

    # Aussi diffusé sur le salon de l'article : les lecteurs qui regardent
    # la fiche en ce moment voient la nouvelle moyenne sans recharger.
    try:
        from asgiref.sync import async_to_sync
        from channels.layers import get_channel_layer

        channel_layer = get_channel_layer()
        if channel_layer is not None:
            async_to_sync(channel_layer.group_send)(
                f'conversation_{instance.publication_id}',
                {'type': 'new_message', 'payload': {'event': 'review_updated'}},
            )
    except Exception:
        logger.exception("Echec diffusion WebSocket du nouvel avis pour %s", instance.id)
