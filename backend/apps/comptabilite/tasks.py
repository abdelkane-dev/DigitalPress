"""
Tâches Celery — traitement asynchrone Digital Press.
"""
from celery import shared_task
from celery.utils.log import get_task_logger
from django.utils import timezone
from datetime import timedelta

logger = get_task_logger(__name__)


@shared_task(bind=True, max_retries=3, default_retry_delay=60)
def calculer_reconciliation_mensuelle(self, annee=None, mois=None):
    """Calcule et sauvegarde la réconciliation comptable du mois donné."""
    try:
        from .utils import calculer_reconciliation
        from .models import ReconciliationComptable

        now = timezone.now()
        annee = annee or now.year
        mois = mois or now.month

        stats = calculer_reconciliation(annee, mois)
        rec, created = ReconciliationComptable.objects.update_or_create(
            periode_annee=annee,
            periode_mois=mois,
            defaults={
                'total_recettes': stats['total_recettes'],
                'total_commissions': stats['total_commissions'],
                'total_retraits': stats['total_retraits'],
                'total_remboursements': stats['total_remboursements'],
                'solde_theorique': stats['solde_theorique'],
                'solde_reel': stats['solde_reel'],
                'ecart': stats['ecart'],
                'nb_transactions': stats['nb_transactions'],
                'nb_ecritures': stats['nb_ecritures'],
                'status': stats['status'],
            }
        )
        action = 'créée' if created else 'mise à jour'
        logger.info("Réconciliation %02d/%d %s (écart: %s)", mois, annee, action, stats['ecart'])
        return {'success': True, 'mois': mois, 'annee': annee, 'status': stats['status']}
    except Exception as exc:
        logger.error("Erreur réconciliation: %s", str(exc))
        raise self.retry(exc=exc)


@shared_task(bind=True, max_retries=3, default_retry_delay=30)
def verifier_paiement_pending(self, transaction_id):
    """Vérifie le statut d'une transaction en attente auprès de Movapay."""
    try:
        from apps.paiements.models import Transaction
        from apps.paiements.movapay import movapay_service
        from apps.accounts.models import PublisherProfile
        from .utils import enregistrer_ecriture
        from django.db import transaction as db_tx

        tx = Transaction.objects.get(pk=transaction_id)
        if tx.status != 'pending':
            return {'skipped': True, 'status': tx.status}

        result = movapay_service.verifier_paiement(
            reference=str(tx.reference),
            movapay_ref=tx.movapay_ref,
        )

        if result.get('status') == 'success':
            with db_tx.atomic():
                tx.status = 'success'
                tx.movapay_ref = result.get('movapay_ref', tx.movapay_ref)
                tx.processed_at = timezone.now()
                tx.save()

                if tx.beneficiaire and tx.beneficiaire.role == 'publisher':
                    profile, _ = PublisherProfile.objects.get_or_create(
                        user=tx.beneficiaire,
                        defaults={'company_name': tx.beneficiaire.name}
                    )
                    profile.solde += tx.montant_net
                    profile.total_earned += tx.montant_net
                    profile.save(update_fields=['solde', 'total_earned'])
                enregistrer_ecriture(tx)
                notifier_paiement_reussi.delay(tx.id)

        elif result.get('status') in ('failed', 'cancelled'):
            tx.status = result['status']
            tx.save(update_fields=['status'])

        logger.info("Transaction %s vérifiée: %s", tx.reference, result.get('status'))
        return {'transaction_id': transaction_id, 'new_status': result.get('status')}
    except Transaction.DoesNotExist:
        logger.warning("Transaction %s introuvable.", transaction_id)
        return {'error': 'Transaction introuvable'}
    except Exception as exc:
        logger.error("Erreur vérification paiement %s: %s", transaction_id, str(exc))
        raise self.retry(exc=exc)


@shared_task
def verifier_paiements_pending_batch():
    """Vérifie toutes les transactions en attente de plus de 5 minutes."""
    from apps.paiements.models import Transaction
    cutoff = timezone.now() - timedelta(minutes=5)
    pending = Transaction.objects.filter(
        status='pending',
        created_at__lt=cutoff
    ).values_list('id', flat=True)

    count = 0
    for tx_id in pending:
        verifier_paiement_pending.delay(tx_id)
        count += 1

    logger.info("%d transactions pending envoyées en vérification.", count)
    return {'tasks_dispatched': count}


@shared_task
def notifier_paiement_reussi(transaction_id):
    """Envoie une notification push après paiement réussi."""
    try:
        from apps.paiements.models import Transaction
        from apps.notifications.views import send_notification

        tx = Transaction.objects.select_related('payer', 'beneficiaire').get(pk=transaction_id)

        if tx.payer:
            send_notification(
                user=tx.payer,
                type_notif='payment_success',
                title='Paiement confirmé ✓',
                message=f"Votre paiement de {tx.montant_brut} {tx.devise} a été confirmé.",
                data={'transaction_ref': str(tx.reference)},
            )

        if tx.beneficiaire and tx.beneficiaire.role == 'publisher':
            send_notification(
                user=tx.beneficiaire,
                type_notif='payment_success',
                title='Nouveau paiement reçu 💰',
                message=f"Vous avez reçu {tx.montant_net} {tx.devise} (après commission).",
                data={'transaction_ref': str(tx.reference)},
            )

        logger.info("Notifications paiement envoyées pour transaction %s.", tx.reference)
    except Exception as exc:
        logger.error("Erreur notification paiement: %s", str(exc))


@shared_task
def expirer_abonnements():
    """Marque les abonnements expirés comme 'expired'."""
    from apps.abonnements.models import Abonnement
    from apps.notifications.views import send_notification

    now = timezone.now()
    expired = Abonnement.objects.filter(status='active', end_date__lt=now)
    count = expired.count()

    for ab in expired:
        ab.status = 'expired'
        ab.save(update_fields=['status'])
        send_notification(
            user=ab.reader,
            type_notif='subscription_expired',
            title='Abonnement expiré',
            message=f"Votre abonnement a expiré. Renouvelez-le pour continuer à accéder au contenu.",
            data={'abonnement_id': ab.id},
        )

    logger.info("%d abonnements expirés traités.", count)
    return {'expired_count': count}


@shared_task
def expirer_abonnements_editeurs():
    """DÉSACTIVÉE : le palier plateforme éditeur (Basique/Standard/Premium)
    est désormais gratuit et automatique, sans date d'expiration — voir
    apps.abonnements.services.sync_publisher_tier. Cette tâche ne doit plus
    jamais retirer PublisherProfile.is_active : conservée uniquement pour
    ne pas casser la planification Celery Beat existante si elle est encore
    référencée ailleurs ; elle ne fait plus rien.
    """
    logger.info("expirer_abonnements_editeurs() : no-op (palier éditeur gratuit, sans expiration).")
    return {'expired_count': 0}


@shared_task
def nettoyer_transactions_abandonnees():
    """Annule les transactions pending de plus de 24h."""
    from apps.paiements.models import Transaction
    cutoff = timezone.now() - timedelta(hours=24)
    updated = Transaction.objects.filter(
        status='pending', created_at__lt=cutoff
    ).update(status='cancelled')
    logger.info("%d transactions abandonnées annulées.", updated)
    return {'cancelled_count': updated}


@shared_task
def notifier_expiration_proche():
    """
    Envoie une notification d'avertissement aux abonnés dont l'abonnement
    expire dans exactement 3 jours (fenêtre de 1 heure autour de minuit).
    Exécutée chaque nuit à 00:30 pour maximiser la couverture.
    """
    from apps.abonnements.models import Abonnement
    from apps.notifications.views import send_notification

    now = timezone.now()
    # Fenêtre : expiration entre 2j 23h et 3j 1h (pour absorber les décalages)
    window_start = now + timedelta(days=2, hours=23)
    window_end = now + timedelta(days=3, hours=1)

    soon_expiring = Abonnement.objects.filter(
        status='active',
        end_date__gte=window_start,
        end_date__lte=window_end,
    ).select_related('reader', 'publisher')

    count = 0
    for ab in soon_expiring:
        publisher_name = 'la presse'
        if ab.publisher:
            if hasattr(ab.publisher, 'publisher_profile'):
                publisher_name = ab.publisher.publisher_profile.company_name
            else:
                publisher_name = ab.publisher.name or ab.publisher.username

        send_notification(
            user=ab.reader,
            type_notif='subscription_expiring_soon',
            title='⏰ Abonnement bientôt expiré',
            message=(
                f"Votre abonnement à {publisher_name} expire dans 3 jours "
                f"(le {ab.end_date.strftime('%d/%m/%Y')}). "
                "Renouvelez-le pour continuer à accéder au contenu."
            ),
            data={'abonnement_id': ab.id},
        )
        count += 1

    logger.info("%d notifications d'expiration proche envoyées.", count)
    return {'notified_count': count}


@shared_task
def recalculer_tous_soldes():
    """Recalcule les soldes de tous les éditeurs depuis les transactions."""
    from apps.accounts.models import PublisherProfile
    from apps.paiements.models import Transaction
    from django.db.models import Sum

    updated = 0
    for profile in PublisherProfile.objects.select_related('user').all():
        recu = Transaction.objects.filter(
            beneficiaire=profile.user, status='success'
        ).aggregate(t=Sum('montant_net'))['t'] or 0

        retire = Transaction.objects.filter(
            payer=profile.user, type_transaction='withdrawal', status='success'
        ).aggregate(t=Sum('montant_brut'))['t'] or 0

        solde = recu - retire
        profile.solde = max(0, solde)
        profile.total_earned = recu
        profile.save(update_fields=['solde', 'total_earned'])
        updated += 1

    logger.info("Soldes recalculés pour %d éditeurs.", updated)
    return {'updated_count': updated}


@shared_task
def traiter_payouts_presse_automatique():
    """
    Tâche automatique : traite toutes les demandes de retrait approuvées.
    Exécutée chaque nuit à 01h00. Pour chaque demande 'approved', elle :
    - Débite le solde de l'éditeur
    - Crée une transaction 'withdrawal' en succès
    - Passe la demande à 'completed'
    - Notifie l'éditeur
    """
    from apps.paiements.models import Transaction, DemandeRetrait
    from apps.accounts.models import PublisherProfile
    from apps.notifications.views import send_notification
    from django.db import transaction as db_tx

    approved = DemandeRetrait.objects.filter(status='approved').select_related('editeur')
    count = 0
    errors = 0

    for demande in approved:
        try:
            with db_tx.atomic():
                profile = PublisherProfile.objects.select_for_update().get(user=demande.editeur)
                if profile.solde < demande.montant:
                    logger.warning(
                        "Payout ignoré pour %s : solde %s < montant %s",
                        demande.editeur.username, profile.solde, demande.montant,
                    )
                    continue

                # Débit du solde
                profile.solde -= demande.montant
                profile.save(update_fields=['solde'])

                # Créer la transaction de retrait
                tx = Transaction.objects.create(
                    payer=demande.editeur,
                    type_transaction='withdrawal',
                    montant_brut=demande.montant,
                    commission=0,
                    montant_net=demande.montant,
                    status='success',
                    processed_at=timezone.now(),
                    description=f'Payout auto — {demande.editeur.username}',
                )

                # Clore la demande
                demande.status = 'completed'
                demande.transaction = tx
                demande.save(update_fields=['status', 'transaction'])

                # Notifier l'éditeur
                send_notification(
                    user=demande.editeur,
                    type_notif='withdrawal_completed',
                    title='Virement effectué 💸',
                    message=(
                        f"Votre retrait de {demande.montant} FCFA a été traité automatiquement. "
                        "Les fonds devraient arriver sous 24-48h."
                    ),
                    data={'montant': str(demande.montant), 'transaction_ref': str(tx.reference)},
                )
                count += 1
        except Exception as exc:
            errors += 1
            logger.error("Erreur payout auto pour %s : %s", demande.editeur.username, str(exc))

    logger.info("Payouts automatiques : %d traités, %d erreurs.", count, errors)
    return {'processed': count, 'errors': errors}
