import logging

from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver

from .models import FeatureItem

logger = logging.getLogger('apps')


@receiver(post_save, sender=FeatureItem)
def broadcast_feature_saved(sender, instance, created, **kwargs):
    from apps.notifications.realtime import push_to_admins_and_publishers
    push_to_admins_and_publishers('roadmap_changed', {})


@receiver(post_delete, sender=FeatureItem)
def broadcast_feature_deleted(sender, instance, **kwargs):
    from apps.notifications.realtime import push_to_admins_and_publishers
    push_to_admins_and_publishers('roadmap_changed', {})
