"""Diffuse chaque Transaction créée/mise à jour en temps réel :
- à l'éditeur bénéficiaire (ses statistiques/solde changent)
- au payeur (son historique d'achats change)
- à tous les admins connectés (tableau de bord admin = vue d'ensemble
  plateforme, doit refléter chaque transaction sans rafraîchissement)
"""
import logging

from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import Transaction, DemandeRetrait

logger = logging.getLogger('apps')


@receiver(post_save, sender=Transaction)
def broadcast_transaction(sender, instance, created, **kwargs):
    try:
        from apps.notifications.realtime import push_to_user, push_to_admins

        push_to_user(instance.payer_id, 'stats_changed', {'reason': 'transaction'})
        if instance.beneficiaire_id:
            push_to_user(instance.beneficiaire_id, 'stats_changed', {'reason': 'transaction'})
        push_to_admins('admin_stats_changed', {'reason': 'transaction'})
    except Exception:
        logger.exception("Echec diffusion WebSocket pour transaction %s", instance.id)

    # Une vente réussie peut faire progresser le palier de l'éditeur
    # bénéficiaire (voir apps.abonnements.services.sync_publisher_tier —
    # accès gratuit, progression automatique selon l'activité réelle).
    if instance.status == 'success' and instance.beneficiaire_id:
        try:
            from apps.abonnements.services import sync_publisher_tier
            sync_publisher_tier(instance.beneficiaire)
        except Exception:
            logger.exception("Echec verification de palier pour transaction %s", instance.id)


@receiver(post_save, sender=DemandeRetrait)
def broadcast_withdrawal(sender, instance, created, **kwargs):
    """Une demande de retrait éditeur doit alerter les admins en direct
    (file d'attente à traiter), et l'éditeur en direct quand son statut
    change (approuvé/rejeté/complété)."""
    try:
        from apps.notifications.realtime import push_to_user, push_to_admins

        push_to_user(instance.editeur_id, 'stats_changed', {'reason': 'withdrawal'})
        if created:
            push_to_admins('admin_stats_changed', {'reason': 'new_withdrawal'})
    except Exception:
        logger.exception("Echec diffusion WebSocket pour retrait %s", instance.id)
