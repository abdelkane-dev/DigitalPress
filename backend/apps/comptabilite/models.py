from django.db import models
from django.utils.translation import gettext_lazy as _
from django.utils import timezone


class EcritureComptable(models.Model):
    """Journal comptable — chaque transaction génère une écriture."""

    TYPE_CHOICES = [
        ('recette', 'Recette'),
        ('depense', 'Dépense'),
        ('commission', 'Commission plateforme'),
        ('retrait', 'Retrait éditeur'),
        ('remboursement', 'Remboursement'),
        ('regularisation', 'Régularisation'),
    ]

    COMPTE_CHOICES = [
        ('411000', 'Clients'),
        ('401000', 'Fournisseurs / Éditeurs'),
        ('706000', 'Prestations de services'),
        ('708000', 'Commissions'),
        ('512000', 'Banque / Mobile Money'),
        ('471000', 'Compte d\'attente'),
        ('445800', 'TVA collectée'),
        ('627000', 'Frais bancaires'),
    ]

    reference = models.CharField(max_length=100, unique=True)
    # ─── CORRECTION CRITIQUE ────────────────────────────────────────────
    # Ce champ était un OneToOneField, mais `enregistrer_ecriture()` crée
    # DEUX écritures pour une même transaction dès qu'une commission est
    # appliquée (l'écriture principale + l'écriture de commission). Cela
    # provoquait systématiquement une IntegrityError (contrainte unique
    # violée) silencieusement avalée par un try/except plus haut dans la
    # pile d'appel — ce qui annulait TOUT le bloc atomique englobant et
    # empêchait donc, à chaque paiement avec commission, la validation
    # réelle du paiement : le statut restait "pending", le solde de
    # l'éditeur n'était jamais crédité et l'abonnement jamais activé,
    # bien que Movapay ait confirmé le paiement avec succès.
    transaction = models.ForeignKey(
        'paiements.Transaction', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='ecritures'
    )
    date_ecriture = models.DateTimeField(default=timezone.now)
    type_ecriture = models.CharField(max_length=20, choices=TYPE_CHOICES)
    compte_debit = models.CharField(max_length=20, choices=COMPTE_CHOICES)
    compte_credit = models.CharField(max_length=20, choices=COMPTE_CHOICES)
    libelle = models.CharField(max_length=500)
    montant = models.DecimalField(max_digits=14, decimal_places=2)
    montant_commission = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    editeur = models.ForeignKey(
        'accounts.User', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='ecritures_editeur'
    )
    client = models.ForeignKey(
        'accounts.User', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='ecritures_client'
    )
    publication = models.ForeignKey(
        'publications.Publication', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='ecritures'
    )
    devise = models.CharField(max_length=10, default='FCFA')
    periode_mois = models.PositiveSmallIntegerField()
    periode_annee = models.PositiveSmallIntegerField()
    is_reconciled = models.BooleanField(default=False)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = _('Écriture comptable')
        verbose_name_plural = _('Écritures comptables')
        ordering = ['-date_ecriture']
        indexes = [
            models.Index(fields=['periode_annee', 'periode_mois']),
            models.Index(fields=['editeur']),
            models.Index(fields=['type_ecriture']),
            models.Index(fields=['is_reconciled']),
        ]

    def __str__(self):
        return f"[{self.reference}] {self.libelle} — {self.montant} {self.devise}"


class ReconciliationComptable(models.Model):
    """Réconciliation mensuelle entre les transactions et le journal."""

    STATUS_CHOICES = [
        ('en_cours', 'En cours'),
        ('reconciled', 'Réconcilié'),
        ('anomalie', 'Anomalie détectée'),
    ]

    periode_mois = models.PositiveSmallIntegerField()
    periode_annee = models.PositiveSmallIntegerField()
    total_recettes = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    total_commissions = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    total_retraits = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    total_remboursements = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    solde_theorique = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    solde_reel = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    ecart = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    nb_transactions = models.PositiveIntegerField(default=0)
    nb_ecritures = models.PositiveIntegerField(default=0)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='en_cours')
    notes = models.TextField(blank=True)
    reconciled_by = models.ForeignKey(
        'accounts.User', on_delete=models.SET_NULL, null=True, blank=True
    )
    reconciled_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = _('Réconciliation comptable')
        verbose_name_plural = _('Réconciliations comptables')
        unique_together = ['periode_annee', 'periode_mois']
        ordering = ['-periode_annee', '-periode_mois']

    def __str__(self):
        return f"Réconciliation {self.periode_mois:02d}/{self.periode_annee} — {self.status}"
