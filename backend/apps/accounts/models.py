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
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='reader')
    name = models.CharField(max_length=255, blank=True)
    phone = models.CharField(max_length=20, blank=True)
    avatar = models.URLField(blank=True)
    billing_address = models.TextField(blank=True, default='', help_text='Adresse de facturation')
    billing_phone = models.CharField(max_length=25, blank=True, default='', help_text='Numéro de facturation / contact')
    is_verified = models.BooleanField(default=False)
    solde = models.DecimalField(max_digits=12, decimal_places=2, default=0.00, help_text="Solde portefeuille client/lecteur")
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

    @property
    def badge_label(self):
        """Libellé de badge de compte à afficher PARTOUT où l'auteur d'un
        contenu est visible (profil, commentaires, conversations...) — voir
        User.membershipBadgeLabel côté Flutter, qui doit rester le miroir
        exact de cette logique. Centralisé ici pour que tous les
        serializers (commentaires, messages, notifications...) exposent la
        même valeur sans dupliquer la règle à chaque endroit.
        `None` = aucun badge à afficher.
        """
        if self.role == 'admin':
            return 'Super utilisateur'
        if self.role == 'publisher':
            if not self.is_verified:
                return None
            sub = self.platform_subscriptions.filter(status='active').select_related('plan').first()
            plan_name = sub.plan.name if (sub and sub.plan) else None
            if plan_name is None or plan_name == 'Basique':
                return None
            return f'Membre {plan_name}'
        return 'Compte vérifié' if self.is_verified else None


class PublisherProfile(models.Model):
    user = models.OneToOneField(
        User, on_delete=models.CASCADE, related_name='publisher_profile'
    )
    company_name = models.CharField(max_length=255)
    siret = models.CharField(max_length=20, blank=True)
    address = models.TextField(blank=True)
    website = models.URLField(blank=True)
    bio = models.TextField(blank=True)
    # Couverture/bannière du profil public (façon TikTok) — image uploadée,
    # distincte de l'avatar (User.avatar).
    cover_image = models.URLField(
        blank=True, default='',
        help_text="Image de couverture de la page publique du profil éditeur"
    )
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


class EmailVerificationCode(models.Model):
    """Code OTP de vérification d'email à la création de compte.

    (Note Dr. Sissoko, 2026-08-16) : chaque création de compte — quel que
    soit le type de profil (lecteur, éditeur, admin) — exige désormais une
    validation par email pour activer le compte. L'utilisateur reçoit un
    OTP à 6 chiffres avec une durée de vie de 15 minutes (contrairement au
    code de réinitialisation de mot de passe, valable 10 min).

    Comme pour PasswordResetCode, le code brut n'est jamais stocké : seul
    son hash SHA-256 est conservé, avec une expiration courte et un nombre
    maximal de tentatives.
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='email_verification_codes')
    code_hash = models.CharField(max_length=64)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_used = models.BooleanField(default=False)
    attempts = models.PositiveSmallIntegerField(default=0)

    class Meta:
        verbose_name = _('Code de vérification email')
        verbose_name_plural = _('Codes de vérification email')
        ordering = ['-created_at']

    @staticmethod
    def hash_code(raw_code: str) -> str:
        return hashlib.sha256(raw_code.encode('utf-8')).hexdigest()

    @classmethod
    def issue_for(cls, user, validity_minutes: int = 15):
        """Génère un nouveau code à 6 chiffres, invalide les précédents et
        le retourne en clair (pour l'envoyer par email)."""
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

    def __str__(self):
        return f"Email verification code for {self.user.username} (used={self.is_used})"


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

    def __str__(self):
        return f"Reset code for {self.user.username} (used={self.is_used})"


# ─── ÉTAPE 1/2 DE L'ONBOARDING ÉDITEUR : VÉRIFICATION DE LÉGITIMITÉ ──────
# Ordre : (1) admin crée le compte, accès immédiat et gratuit -> (2)
# l'éditeur remplit CE formulaire pour prouver que c'est une vraie
# entreprise/agence de presse -> (3) admin valide ou rejette (notification
# + email). La validation n'est plus une condition d'accès à la
# plateforme (accès déjà actif dès la création) : elle sert uniquement au
# badge de légitimité affiché côté admin/modération.
class PublisherVerification(models.Model):
    STATUS_CHOICES = [
        ('pending', 'En attente de vérification'),
        ('approved', 'Validée'),
        ('rejected', 'Rejetée'),
    ]

    user = models.OneToOneField(
        User, on_delete=models.CASCADE, related_name='verification',
        limit_choices_to={'role': 'publisher'}
    )

    # Identité légale de l'entreprise/agence de presse
    legal_company_name = models.CharField(max_length=255, help_text="Raison sociale exacte")
    registration_number = models.CharField(
        max_length=100, help_text="Numéro RCCM / registre du commerce (ou équivalent local)"
    )
    tax_id = models.CharField(
        max_length=100, help_text="NIF / numéro d'identification fiscale"
    )
    official_address = models.TextField(help_text="Adresse physique complète du siège")
    city = models.CharField(max_length=100)
    country = models.CharField(max_length=100)
    phone_number = models.CharField(max_length=30)

    # Représentant légal
    legal_representative_name = models.CharField(max_length=255)
    legal_representative_id_number = models.CharField(
        max_length=100, help_text="N° CNI / passeport du représentant légal"
    )

    # Preuve d'activité de presse (facultatif selon pays, mais valorisé)
    press_accreditation_number = models.CharField(
        max_length=100, blank=True,
        help_text="N° d'accréditation presse / conseil de presse, si applicable"
    )
    website = models.URLField(blank=True)

    # Documents justificatifs (URLs — uploadés via MediaUploadView, déjà
    # sécurisé : whitelist d'extensions + limite de taille)
    id_document_url = models.URLField(help_text="Pièce d'identité du représentant légal")
    registration_document_url = models.URLField(help_text="Certificat RCCM / registre du commerce")
    additional_document_url = models.URLField(blank=True, help_text="Licence de presse ou autre justificatif")

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    rejection_reason = models.TextField(blank=True)
    submitted_at = models.DateTimeField(auto_now_add=True)
    reviewed_at = models.DateTimeField(null=True, blank=True)
    reviewed_by = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='verifications_reviewed', limit_choices_to={'role': 'admin'}
    )
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = _("Vérification d'éditeur")
        verbose_name_plural = _("Vérifications d'éditeurs")
        ordering = ['-submitted_at']

    def __str__(self):
        return f"Vérification {self.user.username} ({self.status})"

    @property
    def is_overdue(self):
        """Dépassement du délai de 24h annoncé à l'éditeur, pour repérage
        visuel côté admin — n'empêche rien techniquement, juste un signal."""
        if self.status != 'pending':
            return False
        return timezone.now() - self.submitted_at > timezone.timedelta(hours=24)


class AccountActionLog(models.Model):
    """Historique des actions de modération d'un compte (suspension, ban,
    réactivation) — permet à l'admin de voir sur la page de détail si un
    utilisateur a déjà été suspendu/banni, par qui et pourquoi."""
    ACTION_CHOICES = [
        ('suspend', 'Suspension'),
        ('ban', 'Bannissement'),
        ('reactivate', 'Réactivation'),
    ]

    user = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name='account_actions'
    )
    action = models.CharField(max_length=20, choices=ACTION_CHOICES)
    reason = models.TextField(blank=True)
    performed_by = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='account_actions_performed'
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = _("Action de modération")
        verbose_name_plural = _("Actions de modération")
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.get_action_display()} — {self.user.username} ({self.created_at:%d/%m/%Y %H:%M})"
