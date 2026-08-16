"""
Tâches Celery — mises en avant « À la une » des publications.
"""
from celery import shared_task
from celery.utils.log import get_task_logger
from django.utils import timezone

logger = get_task_logger(__name__)


@shared_task
def expirer_mises_en_avant():
    """Fait expirer les mises en avant payantes terminées : repasse
    `Publication.is_featured` à False dès que la promotion atteint sa date
    de fin, pour que l'accueil ne mette plus en avant un contenu dont la
    période publicitaire est écoulée (façon publicité Facebook).

    Exécutée chaque nuit (voir CELERY_BEAT_SCHEDULE dans config/settings.py).
    """
    from .models import FeaturedPromotion

    now = timezone.now()
    ended = FeaturedPromotion.objects.filter(
        status='active',
        ends_at__lt=now,
    ).select_related('publication')

    count = 0
    for promo in ended:
        promo.status = 'expired'
        promo.save(update_fields=['status'])
        pub = promo.publication
        # Ne retire la mise en avant que si aucune autre promotion active ne
        # couvre encore cette publication.
        still_active = pub.featured_promotions.filter(status='active').exists()
        if not still_active and pub.is_featured:
            pub.is_featured = False
            pub.save(update_fields=['is_featured'])
        count += 1

    logger.info("%d mises en avant expirées traitées.", count)
    return {'expired_count': count}
