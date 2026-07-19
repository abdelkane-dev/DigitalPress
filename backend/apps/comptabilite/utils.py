"""
Utilitaires comptables — enregistrement automatique des écritures,
calcul de réconciliation, export CSV/Excel.
"""
import uuid
import csv
import io
from decimal import Decimal
from django.utils import timezone
from django.db.models import Sum, Count, Q


def _gen_ref():
    return f"EC-{timezone.now().strftime('%Y%m%d')}-{uuid.uuid4().hex[:8].upper()}"


def enregistrer_ecriture(transaction):
    """
    Enregistre une écriture comptable à partir d'une Transaction validée.
    Appelé automatiquement après confirmation Movapay.
    """
    from .models import EcritureComptable

    # Évite les doublons
    if EcritureComptable.objects.filter(transaction=transaction).exists():
        return None

    now = transaction.processed_at or timezone.now()
    type_map = {
        'subscription': 'recette',
        'purchase': 'recette',
        'withdrawal': 'retrait',
        'commission': 'commission',
        'refund': 'remboursement',
    }

    # Écriture principale (montant brut)
    ecriture = EcritureComptable.objects.create(
        reference=_gen_ref(),
        transaction=transaction,
        date_ecriture=now,
        type_ecriture=type_map.get(transaction.type_transaction, 'recette'),
        compte_debit='512000',    # Banque / Mobile Money
        compte_credit='706000',   # Prestations de services
        libelle=transaction.description or f"Transaction {transaction.reference}",
        montant=transaction.montant_brut,
        montant_commission=transaction.commission,
        editeur=transaction.beneficiaire,
        client=transaction.payer,
        publication=transaction.publication,
        devise=transaction.devise,
        periode_mois=now.month,
        periode_annee=now.year,
    )

    # Écriture commission séparée si applicable
    if transaction.commission and transaction.commission > 0:
        EcritureComptable.objects.create(
            reference=_gen_ref(),
            transaction=transaction,
            date_ecriture=now,
            type_ecriture='commission',
            compte_debit='706000',   # Prestations de services
            compte_credit='708000',  # Commissions
            libelle=f"Commission 10% — {transaction.reference}",
            montant=transaction.commission,
            montant_commission=transaction.commission,
            editeur=transaction.beneficiaire,
            client=transaction.payer,
            devise=transaction.devise,
            periode_mois=now.month,
            periode_annee=now.year,
        )

    return ecriture


def calculer_reconciliation(annee: int, mois: int) -> dict:
    """Calcule les totaux pour une réconciliation mensuelle."""
    from apps.paiements.models import Transaction
    from .models import EcritureComptable

    period_filter = Q(created_at__year=annee, created_at__month=mois)
    ec_filter = Q(periode_annee=annee, periode_mois=mois)

    tx_agg = Transaction.objects.filter(
        period_filter, status='success'
    ).aggregate(
        total_brut=Sum('montant_brut'),
        total_commission=Sum('commission'),
        total_net=Sum('montant_net'),
        count=Count('id'),
    )

    ec_agg = EcritureComptable.objects.filter(ec_filter).aggregate(
        total=Sum('montant'),
        count=Count('id'),
    )

    retraits = Transaction.objects.filter(
        period_filter, status='success', type_transaction='withdrawal'
    ).aggregate(total=Sum('montant_brut'))

    remboursements = Transaction.objects.filter(
        period_filter, status='refunded'
    ).aggregate(total=Sum('montant_brut'))

    total_recettes = Decimal(str(tx_agg.get('total_brut') or 0))
    total_commissions = Decimal(str(tx_agg.get('total_commission') or 0))
    total_retraits = Decimal(str(retraits.get('total') or 0))
    total_remboursements = Decimal(str(remboursements.get('total') or 0))
    solde_theorique = total_recettes - total_commissions - total_retraits - total_remboursements
    solde_reel = Decimal(str(ec_agg.get('total') or 0))

    return {
        'total_recettes': total_recettes,
        'total_commissions': total_commissions,
        'total_retraits': total_retraits,
        'total_remboursements': total_remboursements,
        'solde_theorique': solde_theorique,
        'solde_reel': solde_reel,
        'ecart': abs(solde_theorique - solde_reel),
        'nb_transactions': tx_agg.get('count') or 0,
        'nb_ecritures': ec_agg.get('count') or 0,
        'status': 'reconciled' if abs(solde_theorique - solde_reel) < Decimal('0.01') else 'anomalie',
    }


def export_journal_csv(queryset) -> str:
    """Génère un CSV du journal comptable."""
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        'Référence', 'Date', 'Type', 'Compte Débit', 'Compte Crédit',
        'Libellé', 'Montant', 'Commission', 'Éditeur', 'Client',
        'Publication', 'Devise', 'Période', 'Réconcilié',
    ])
    for e in queryset:
        writer.writerow([
            e.reference,
            e.date_ecriture.strftime('%Y-%m-%d %H:%M'),
            e.get_type_ecriture_display(),
            e.compte_debit,
            e.compte_credit,
            e.libelle,
            str(e.montant),
            str(e.montant_commission),
            e.editeur.username if e.editeur else '',
            e.client.username if e.client else '',
            e.publication.title if e.publication else '',
            e.devise,
            f"{e.periode_mois:02d}/{e.periode_annee}",
            'Oui' if e.is_reconciled else 'Non',
        ])
    return output.getvalue()


def export_transactions_csv(queryset) -> str:
    """Génère un CSV des transactions."""
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        'Référence', 'Date', 'Type', 'Payeur', 'Bénéficiaire',
        'Publication', 'Montant Brut', 'Commission', 'Montant Net',
        'Devise', 'Statut', 'Réf Movapay',
    ])
    for t in queryset:
        writer.writerow([
            t.reference,
            t.created_at.strftime('%Y-%m-%d %H:%M'),
            t.get_type_transaction_display(),
            t.payer.username if t.payer else '',
            t.beneficiaire.username if t.beneficiaire else '',
            t.publication.title if t.publication else '',
            str(t.montant_brut),
            str(t.commission),
            str(t.montant_net),
            t.devise,
            t.get_status_display(),
            t.movapay_ref,
        ])
    return output.getvalue()


def get_dashboard_stats() -> dict:
    """KPIs du dashboard admin."""
    from apps.paiements.models import Transaction
    from apps.accounts.models import User, PublisherProfile
    from apps.abonnements.models import Abonnement

    now = timezone.now()

    tx_success = Transaction.objects.filter(status='success')
    this_month = tx_success.filter(created_at__year=now.year, created_at__month=now.month)
    last_month_date = (now.replace(day=1) - timezone.timedelta(days=1))
    last_month = tx_success.filter(
        created_at__year=last_month_date.year,
        created_at__month=last_month_date.month,
    )

    revenue_month = this_month.aggregate(t=Sum('montant_brut'))['t'] or 0
    revenue_last = last_month.aggregate(t=Sum('montant_brut'))['t'] or 0
    commission_month = this_month.aggregate(t=Sum('commission'))['t'] or 0

    growth = 0
    if revenue_last > 0:
        growth = round(((float(revenue_month) - float(revenue_last)) / float(revenue_last)) * 100, 1)

    total_revenue = tx_success.aggregate(t=Sum('montant_brut'))['t'] or 0
    total_commission = tx_success.aggregate(t=Sum('commission'))['t'] or 0
    total_withdrawals = Transaction.objects.filter(
        type_transaction='withdrawal', status='success'
    ).aggregate(t=Sum('montant_brut'))['t'] or 0

    return {
        'total_users': User.objects.count(),
        'total_publishers': User.objects.filter(role='publisher').count(),
        'total_readers': User.objects.filter(role='reader').count(),
        'total_transactions': tx_success.count(),
        'revenue_total': str(total_revenue),
        'revenue_month': str(revenue_month),
        'revenue_last_month': str(revenue_last),
        'revenue_growth_pct': growth,
        'commission_month': str(commission_month),
        'commission_total': str(total_commission),
        'active_subscriptions': Abonnement.objects.filter(status='active').count(),
        'soldes_editeurs': str(
            PublisherProfile.objects.aggregate(t=Sum('solde'))['t'] or 0
        ),
        'chiffre_affaires_brut': str(total_revenue),
        'commissions_collectees': str(total_commission),
        'retraits_valides': str(total_withdrawals),
        'nb_transactions_success': tx_success.count(),
    }
