from django.db import models
from django.utils.translation import gettext_lazy as _
import uuid


class Transaction(models.Model):
    TYPE_CHOICES = [
        ('subscription', 'Abonnement'),
        ('platform_subscription', 'Abonnement plateforme (éditeur)'),
        ('purchase', 'Achat unitaire'),
        ('resell_right', 'Achat de droit de revente'),
        ('featured', 'Mise en avant (À la une)'),
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
    publisher_subscription = models.ForeignKey(
        'abonnements.PublisherSubscription', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='transactions'
    )
    type_transaction = models.CharField(max_length=50, choices=TYPE_CHOICES)
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


class WithdrawalVerificationCode(models.Model):
    """Code OTP de confirmation d'une demande de retrait d'argent.

    (Demande explicite) : avant de valider une demande de retrait, le
    titulaire du compte doit prouver qu'il en est bien le propriétaire en
    saisissant un code à 6 chiffres reçu par email (ou SMS quand un
    fournisseur SMS sera configuré) — protection contre les retraits
    frauduleux sur les comptes éditeurs.

    Même conception que EmailVerificationCode / PasswordResetCode : le code
    brut n'est jamais stocké (seul son hash SHA-256 est conservé), courte
    expiration (15 min) et nombre maximal de tentatives (5). Un code ne
    peut servir qu'à UNE SEULE demande de retrait (is_used=True dès qu'il
    est consommé), et un nouveau code invalide tous les précédents.
    """
    user = models.ForeignKey(
        'accounts.User', on_delete=models.CASCADE, related_name='withdrawal_verification_codes'
    )
    code_hash = models.CharField(max_length=64)
    channel = models.CharField(
        max_length=10, default='email',
        choices=[('email', 'Email'), ('sms', 'SMS')],
    )
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_used = models.BooleanField(default=False)
    attempts = models.PositiveSmallIntegerField(default=0)

    class Meta:
        verbose_name = _('Code OTP de retrait')
        verbose_name_plural = _('Codes OTP de retrait')
        ordering = ['-created_at']

    @staticmethod
    def hash_code(raw_code: str) -> str:
        import hashlib
        return hashlib.sha256(raw_code.encode('utf-8')).hexdigest()

    @classmethod
    def issue_for(cls, user, channel: str = 'email', validity_minutes: int = 15):
        """Génère un nouveau code à 6 chiffres, invalide les précédents et
        le retourne en clair (pour l'envoyer par email/SMS)."""
        import secrets
        from django.utils import timezone as _tz
        cls.objects.filter(user=user, is_used=False).update(is_used=True)
        raw_code = f"{secrets.randbelow(1_000_000):06d}"
        cls.objects.create(
            user=user,
            code_hash=cls.hash_code(raw_code),
            channel=channel if channel in ('email', 'sms') else 'email',
            expires_at=_tz.now() + _tz.timedelta(minutes=validity_minutes),
        )
        return raw_code

    def is_valid(self) -> bool:
        from django.utils import timezone as _tz
        return not self.is_used and self.expires_at > _tz.now() and self.attempts < 5

    def __str__(self):
        return f"Withdrawal OTP for {self.user.username} ({self.channel}, used={self.is_used})"
