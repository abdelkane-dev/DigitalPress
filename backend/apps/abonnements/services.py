"""
Attribution automatique du palier éditeur (Basique / Standard / Premium).

Remplace l'ancien système où l'éditeur devait CHOISIR ET PAYER un plan
plateforme pour débloquer l'accès. Désormais :

  - Tout éditeur démarre sur le palier "Basique" dès la création du compte,
    avec un accès immédiat (aucun paiement, aucune validation d'abonnement).
  - Le palier évolue automatiquement (Basique -> Standard -> Premium) dès
    que l'éditeur franchit les seuils définis sur chaque PlatformPlan
    (min_subscribers, min_publications, min_sales), sur la base de :
      * nombre d'abonnés (lecteurs avec un abonnement actif à cet éditeur)
      * nombre de publications créées
      * nombre de ventes (écritures comptables de type 'recette')
  - Il ne redescend jamais automatiquement de palier une fois monté.
  - Le prix de chaque palier n'a plus aucun rôle : la plateforme se
    rémunère uniquement via la commission (`commission_rate`) prélevée
    sur les ventes, jamais via un abonnement payant de l'éditeur.

Ce module doit être appelé (via `sync_publisher_tier`) à chaque événement
qui peut faire évoluer un de ces trois compteurs :
  - un lecteur active un abonnement à un éditeur (apps.abonnements.Abonnement.activate)
  - un éditeur crée une publication (apps.publications.views)
  - une vente est enregistrée (apps.comptabilite.utils.enregistrer_ecriture)
"""
from django.db import transaction as db_transaction


def _compter_abonnes(publisher):
    from .models import Abonnement
    return Abonnement.objects.filter(
        publisher=publisher, status='active'
    ).values('reader').distinct().count()


def _compter_publications(publisher):
    from apps.publications.models import Publication
    return Publication.objects.filter(publisher=publisher).count()


def _compter_ventes(publisher):
    from apps.comptabilite.models import EcritureComptable
    return EcritureComptable.objects.filter(
        editeur=publisher, type_ecriture='recette'
    ).count()


def determiner_palier(nb_abonnes: int, nb_publications: int, nb_ventes: int):
    """Retourne le PlatformPlan le plus avancé dont TOUS les seuils non-nuls
    sont atteints SIMULTANÉMENT (logique AND) :
    abonnés ET publications ET ventes doivent tous être franchis pour accéder
    au palier supérieur.
    Un palier dont tous les seuils sont à 0 (typiquement "Basique") est
    automatiquement attribué au départ."""
    from .models import PlatformPlan

    meilleur = None
    for plan in PlatformPlan.objects.filter(is_active=True).order_by('min_subscribers'):
        sub_th = plan.min_subscribers or 0
        pub_th = plan.min_publications or 0
        sales_th = plan.min_sales or 0

        if sub_th == 0 and pub_th == 0 and sales_th == 0:
            seuils_ok = True
        else:
            seuils_ok = (
                (sub_th == 0 or nb_abonnes >= sub_th)
                and (pub_th == 0 or nb_publications >= pub_th)
                and (sales_th == 0 or nb_ventes >= sales_th)
            )

        if seuils_ok:
            meilleur = plan
    return meilleur


@db_transaction.atomic
def sync_publisher_tier(publisher):
    """Recalcule et applique le palier d'un éditeur. Aucune notion de
    paiement : l'accès plateforme (`PublisherProfile.is_active`) reste
    toujours True pour un éditeur validé — seul le palier d'avantages
    change. Ne rétrograde jamais un palier déjà atteint."""
    from apps.accounts.models import PublisherProfile
    from .models import PlatformPlan, PublisherSubscription

    if not getattr(publisher, 'is_publisher', False) and publisher.role != 'publisher':
        return None

    profile, _ = PublisherProfile.objects.get_or_create(
        user=publisher, defaults={'company_name': publisher.name or publisher.username}
    )
    # L'accès plateforme n'est plus conditionné à un paiement : un éditeur
    # créé par l'admin (voir AdminCreatePublisherSerializer) est actif dès
    # la création.
    if not profile.is_active:
        profile.is_active = True
        profile.save(update_fields=['is_active'])

    nb_abonnes = _compter_abonnes(publisher)
    nb_publications = _compter_publications(publisher)
    nb_ventes = _compter_ventes(publisher)

    palier_cible = determiner_palier(nb_abonnes, nb_publications, nb_ventes)
    if palier_cible is None:
        palier_cible = PlatformPlan.objects.filter(
            is_active=True, name='Basique'
        ).first()
    if palier_cible is None:
        return None

    current = PublisherSubscription.objects.filter(
        publisher=publisher, status='active'
    ).select_related('plan').order_by('-created_at').first()

    # Ne jamais rétrograder : on ne remplace que si le palier cible est
    # strictement plus avancé (seuil d'abonnés plus élevé) que l'actuel.
    if current and current.plan and current.plan.min_subscribers >= palier_cible.min_subscribers \
            and current.plan_id == palier_cible.id:
        return current

    if current and current.plan_id == palier_cible.id:
        return current

    if current and current.plan and current.plan.min_subscribers > palier_cible.min_subscribers:
        return current

    if current:
        current.status = 'cancelled'
        current.save(update_fields=['status'])

    from django.utils import timezone
    nouveau = PublisherSubscription.objects.create(
        publisher=publisher,
        plan=palier_cible,
        montant=0,
        status='active',
        start_date=timezone.now(),
        end_date=None,
        transaction_ref='auto-palier',
    )

    if not current or (current.plan_id != palier_cible.id):
        from apps.notifications.models import Notification
        Notification.objects.create(
            user=publisher,
            type_notif='subscription_activated',
            title="Nouveau palier débloqué !",
            message=f"Votre compte est passé au palier « {palier_cible.name} » "
                    f"grâce à votre activité. Nouveaux avantages disponibles.",
        )

    return nouveau
