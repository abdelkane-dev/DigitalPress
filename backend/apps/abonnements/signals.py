"""Diffuse chaque Abonnement créé/activé/expiré en temps réel :
- au lecteur concerné (son accès aux contenus change immédiatement)
- à l'éditeur bénéficiaire (ses abonnés changent)
- aux admins (tableau de bord)
"""
import logging

from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import Abonnement

logger = logging.getLogger('apps')


@receiver(post_save, sender=Abonnement)
def broadcast_abonnement(sender, instance, created, **kwargs):
    """Pousse un événement 'abonnement_updated' au lecteur dès qu'un abonnement
    est créé ou change de statut — permet à Flutter de rafraîchir silencieusement
    l'état d'accès (bouton Lire, badge abonné, etc.) sans intervention utilisateur."""
    try:
        from apps.notifications.realtime import push_to_user, push_to_admins

        payload = {
            'abonnement_id': instance.id,
            'status': instance.status,
        }
        if instance.publisher_id:
            payload['publisher_id'] = instance.publisher_id
        if instance.publication_id:
            payload['publication_id'] = instance.publication_id

        # Notifier le lecteur → rafraîchissement UI immédiat
        push_to_user(instance.reader_id, 'abonnement_updated', payload)

        # Notifier l'éditeur → ses statistiques d'abonnés changent
        if instance.publisher_id:
            push_to_user(instance.publisher_id, 'stats_changed', {
                'reason': 'new_subscriber',
                **payload,
            })

        # Notifier les admins
        push_to_admins('admin_stats_changed', {'reason': 'abonnement', **payload})

    except Exception:
        logger.exception("Echec diffusion WebSocket pour abonnement %s", instance.id)
