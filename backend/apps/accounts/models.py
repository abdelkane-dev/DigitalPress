import hashlib
import secrets

from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils import timezone
from django.utils.translation import gettext_lazy as _


class User(AbstractUser):
    ROLE_CHOICES = [
        ('admin', 'Administrateur'),
        ('publisher', 'Éditeur / Entreprise'),
        ('reader', 'Lecteur / Client'),
    ]
    # Email rendu unique pour éviter la création de comptes doublons (point 1)
    email = models.EmailField(unique=True)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='reader')
    name = models.CharField(max_length=255, blank=True)
    phone = models.CharField(max_length=20, blank=True)
    avatar = models.URLField(blank=True)
    is_verified = models.BooleanField(default=False)
    solde = models.DecimalField(max_digits=12, decimal_places=2, default=0.00, help_text="Solde portefeuille client/lecteur")
    # Informations de facturation (point 7)
    billing_address = models.TextField(blank=True, help_text="Adresse de facturation")
    billing_phone = models.CharField(max_length=25, blank=True, help_text="Numéro de facturation / contact")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = _('Utilisateur')
        verbose_name_plural = _('Utilisateurs')
        ordering = ['-date_joined']

    def __str__(self):
        return f"{self.username} ({self.role})"

    @property
    def is_admin(self):
        return self.role == 'admin'

    @property
    def is_publisher(self):
        return self.role == 'publisher'

    @property
    def is_reader(self):
        return self.role == 'reader'


class PublisherProfile(models.Model):
    user = models.OneToOneField(
        User, on_delete=models.CASCADE, related_name='publisher_profile'
    )
    company_name = models.CharField(max_length=255)
    siret = models.CharField(max_length=20, blank=True)
    address = models.TextField(blank=True)
    website = models.URLField(blank=True)
    bio = models.TextField(blank=True)
    solde = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    total_earned = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    commission_rate = models.DecimalField(
        max_digits=5, decimal_places=2, default=10.00,
        help_text="Commission plateforme en % (défaut: 10%)"
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = _('Profil éditeur')
        verbose_name_plural = _('Profils éditeurs')

    def __str__(self):
        return f"{self.company_name} ({self.user.username})"


class PosterWarning(models.Model):
    """Avertissement réel émis par un administrateur à l'encontre d'un éditeur.

    Remplace l'ancien mécanisme purement local (Riverpod) côté Flutter par
    une source de vérité persistée et propre à chaque compte éditeur.
    """
    publisher = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name='warnings_received',
        limit_choices_to={'role': 'publisher'},
    )
    issued_by = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, related_name='warnings_issued',
    )
    reason = models.TextField()
    severity = models.CharField(
        max_length=20,
        choices=[('info', 'Information'), ('warning', 'Avertissement'), ('critical', 'Critique')],
        default='warning',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = _('Avertissement éditeur')
        verbose_name_plural = _('Avertissements éditeurs')
        ordering = ['-created_at']

    def __str__(self):
        return f"⚠ {self.publisher.username} — {self.reason[:40]}"


class PasswordResetCode(models.Model):
    """Code de vérification à usage unique pour la réinitialisation du mot de passe.

    Le code brut n'est jamais stocké : seul son hash SHA-256 est conservé,
    à la manière d'un jeton d'authentification, avec une expiration courte.
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='password_reset_codes')
    code_hash = models.CharField(max_length=64)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_used = models.BooleanField(default=False)
    attempts = models.PositiveSmallIntegerField(default=0)

    class Meta:
        verbose_name = _('Code de réinitialisation')
        verbose_name_plural = _('Codes de réinitialisation')
        ordering = ['-created_at']

    @staticmethod
    def hash_code(raw_code: str) -> str:
        return hashlib.sha256(raw_code.encode('utf-8')).hexdigest()

    @classmethod
    def issue_for(cls, user, validity_minutes: int = 10):
        """Génère un nouveau code à 6 chiffres, invalide les précédents et le retourne en clair."""
        cls.objects.filter(user=user, is_used=False).update(is_used=True)
        raw_code = f"{secrets.randbelow(1_000_000):06d}"
        cls.objects.create(
            user=user,
            code_hash=cls.hash_code(raw_code),
            expires_at=timezone.now() + timezone.timedelta(minutes=validity_minutes),
        )
        return raw_code

    def is_valid(self) -> bool:
        return not self.is_used and self.expires_at > timezone.now() and self.attempts < 5

        return f"Reset code for {self.user.username} (used={self.is_used})"


class NotificationPreference(models.Model):
    """Préférences de notification par utilisateur (point 5 — incohérence notifications).

    Garantit que les notifications ne sont envoyées que sur les canaux
    activés par l'utilisateur, avec la bonne fréquence.
    """
    FREQUENCY_CHOICES = [
        ('immediate', 'Immédiat'),
        ('daily_digest', 'Digest quotidien'),
        ('disabled', 'Désactivé'),
    ]

    user = models.OneToOneField(
        User, on_delete=models.CASCADE, related_name='notification_preference',
    )
    # Canaux d'envoi
    email_enabled = models.BooleanField(default=True, help_text="Activer les notifications email")
    push_enabled = models.BooleanField(default=True, help_text="Activer les notifications push (FCM)")
    sms_enabled = models.BooleanField(default=False, help_text="Activer les notifications SMS")

    # Fréquence
    frequency = models.CharField(
        max_length=20, choices=FREQUENCY_CHOICES, default='immediate',
        help_text="Fréquence des notifications email",
    )

    # Types de notifications actifs
    notify_new_publication = models.BooleanField(default=True)
    notify_payment = models.BooleanField(default=True)
    notify_subscription = models.BooleanField(default=True)

    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = _('Préférence de notification')
        verbose_name_plural = _('Préférences de notification')

    def __str__(self):
        return f"Préfs notif {self.user.username}"
