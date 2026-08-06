from django.db import models
from django.utils.translation import gettext_lazy as _
import uuid


class Transaction(models.Model):
    TYPE_CHOICES = [
        ('subscription', 'Abonnement'),
        ('purchase', 'Achat unitaire'),
        ('resell_right', 'Achat de droit de revente'),
        ('withdrawal', 'Retrait éditeur'),
        ('commission', 'Commission plateforme'),
        ('refund', 'Remboursement'),
    ]
    STATUS_CHOICES = [
        ('pending', 'En attente'),
        ('success', 'Succès'),
        ('failed', 'Échoué'),
        ('cancelled', 'Annulé'),
        ('refunded', 'Remboursé'),
    ]

    reference = models.CharField(max_length=100, unique=True, default=uuid.uuid4)
    movapay_ref = models.CharField(max_length=255, blank=True)
    payer = models.ForeignKey(
        'accounts.User', on_delete=models.SET_NULL, null=True,
        related_name='transactions_emises'
    )
    beneficiaire = models.ForeignKey(
        'accounts.User', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='transactions_recues'
    )
    publication = models.ForeignKey(
        'publications.Publication', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='transactions'
    )
    abonnement = models.ForeignKey(
        'abonnements.Abonnement', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='transactions'
    )
    type_transaction = models.CharField(max_length=20, choices=TYPE_CHOICES)
    montant_brut = models.DecimalField(max_digits=12, decimal_places=2)
    commission = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    montant_net = models.DecimalField(max_digits=12, decimal_places=2)
    devise = models.CharField(max_length=10, default='FCFA')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    metadata = models.JSONField(default=dict, blank=True)
    description = models.TextField(blank=True)
    phone_payer = models.CharField(max_length=20, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    processed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        verbose_name = _('Transaction')
        verbose_name_plural = _('Transactions')
        ordering = ['-created_at']

    def __str__(self):
        return f"[{self.reference}] {self.type_transaction} — {self.montant_brut} {self.devise} ({self.status})"


class DemandeRetrait(models.Model):
    STATUS_CHOICES = [
        ('pending', 'En attente'),
        ('approved', 'Approuvé'),
        ('rejected', 'Rejeté'),
        ('processing', 'En traitement'),
        ('completed', 'Complété'),
    ]

    editeur = models.ForeignKey(
        'accounts.User', on_delete=models.CASCADE, related_name='demandes_retrait'
    )
    montant = models.DecimalField(max_digits=12, decimal_places=2)
    mode_paiement = models.CharField(max_length=50, default='mobile_money')
    numero_compte = models.CharField(max_length=50, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    motif_rejet = models.TextField(blank=True)
    transaction = models.ForeignKey(
        Transaction, on_delete=models.SET_NULL, null=True, blank=True
    )
    traitee_par = models.ForeignKey(
        'accounts.User', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='retraits_traites'
    )
    notes_admin = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = _('Demande de retrait')
        verbose_name_plural = _('Demandes de retrait')
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.editeur.username} — {self.montant} FCFA ({self.status})"
