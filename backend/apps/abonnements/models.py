from django.db import models
from django.utils.translation import gettext_lazy as _
from django.utils import timezone


class Plan(models.Model):
    PERIOD_CHOICES = [
        ('monthly', 'Mensuel'),
        ('quarterly', 'Trimestriel'),
        ('yearly', 'Annuel'),
    ]
    name = models.CharField(max_length=100)
    publisher = models.ForeignKey(
        'accounts.User', on_delete=models.CASCADE, null=True, blank=True,
        related_name='plans', limit_choices_to={'role': 'publisher'}
    )
    description = models.TextField(blank=True)
    prix = models.DecimalField(max_digits=10, decimal_places=2)
    period = models.CharField(max_length=20, choices=PERIOD_CHOICES, default='monthly')
    max_publications = models.PositiveIntegerField(default=0, help_text='0 = illimité')
    features = models.TextField(blank=True, help_text='Fonctionnalités, une par ligne')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = _('Plan d\'abonnement')
        verbose_name_plural = _('Plans d\'abonnement')
        ordering = ['prix']

    def __str__(self):
        return f"{self.name} — {self.prix} FCFA/{self.period}"


class Abonnement(models.Model):
    STATUS_CHOICES = [
        ('active', 'Actif'),
        ('expired', 'Expiré'),
        ('cancelled', 'Annulé'),
        ('pending', 'En attente'),
    ]

    reader = models.ForeignKey(
        'accounts.User', on_delete=models.CASCADE,
        related_name='abonnements', limit_choices_to={'role': 'reader'}
    )
    publication = models.ForeignKey(
        'publications.Publication', on_delete=models.CASCADE,
        related_name='abonnements', null=True, blank=True,
        help_text='Null = abonnement global à la plateforme'
    )
    plan = models.ForeignKey(
        Plan, on_delete=models.SET_NULL, null=True, blank=True
    )
    publisher = models.ForeignKey(
        'accounts.User', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='subscriptions_received', limit_choices_to={'role': 'publisher'}
    )
    montant = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    start_date = models.DateTimeField(null=True, blank=True)
    end_date = models.DateTimeField(null=True, blank=True)
    auto_renew = models.BooleanField(default=False)
    transaction_ref = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = _('Abonnement')
        verbose_name_plural = _('Abonnements')
        ordering = ['-created_at']

    def __str__(self):
        target = self.publication.title if self.publication else 'Plateforme'
        return f"{self.reader.username} → {target} ({self.status})"

    @property
    def is_active(self):
        if self.status != 'active':
            return False
        if self.end_date and timezone.now() > self.end_date:
            return False
        return True

    def activate(self, transaction_ref):
        from django.utils import timezone
        from datetime import timedelta
        
        period_days = {'monthly': 30, 'quarterly': 90, 'yearly': 365}
        days = period_days.get(self.plan.period if self.plan else 'monthly', 30)

        self.status = 'active'
        self.start_date = timezone.now()
        self.end_date = timezone.now() + timedelta(days=days)
        self.transaction_ref = transaction_ref
        self.save()

        # Envoyer une notification
        from apps.notifications.models import Notification
        Notification.objects.create(
            user=self.reader,
            type_notif='subscription_activated',
            title="Abonnement activé !",
            message=f"Votre abonnement à {self.publisher.name if self.publisher else 'la plateforme'} est maintenant actif jusqu'au {self.end_date.strftime('%d/%m/%Y')}."
        )

        # Un nouvel abonné actif peut faire franchir un seuil de palier à
        # l'éditeur (voir apps.abonnements.services.sync_publisher_tier).
        if self.publisher:
            from .services import sync_publisher_tier
            sync_publisher_tier(self.publisher)


# ─── PALIER ÉDITEUR (ÉDITEUR ↔ PLATEFORME) ────────────────────────────────
# Différent de Plan/Abonnement ci-dessus (qui gèrent Lecteur → Éditeur, un
# vrai abonnement payant lecteur-vers-éditeur).
# Ceci gère le PALIER d'avantages d'un Éditeur sur la plateforme — PAS un
# abonnement payant. Aucun paiement n'est jamais demandé à l'éditeur : la
# plateforme se rémunère uniquement via `commission_rate` prélevée sur les
# ventes. Tout éditeur créé par l'admin (voir apps.accounts.AdminCreatePublisherView)
# a PublisherProfile.is_active=True dès la création et démarre au palier
# "Basique" ; il progresse ensuite automatiquement vers "Standard" puis
# "Premium" en fonction de son activité (voir apps.abonnements.services.
# sync_publisher_tier). PublisherProfile.is_active reste la source de
# vérité pour "cet éditeur a-t-il accès à la plateforme" — il ne peut
# désormais être à False que si un admin bannit explicitement le compte.
class PlatformPlan(models.Model):
    PERIOD_CHOICES = [
        ('monthly', 'Mensuel'),
        ('quarterly', 'Trimestriel'),
        ('yearly', 'Annuel'),
    ]
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    prix = models.DecimalField(max_digits=10, decimal_places=2)
    period = models.CharField(max_length=20, choices=PERIOD_CHOICES, default='monthly')
    features = models.TextField(blank=True, help_text='Fonctionnalités, une par ligne (texte affiché)')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    # ─── AVANTAGE RÉEL DU PLAN : MISE EN AVANT ─────────────────────────
    # Sur demande explicite : aucune restriction sur le nombre de
    # publications ni sur le type de contenu (vidéo compris) — ces
    # fonctionnalités existent déjà pour tout le monde et ne doivent
    # jamais être limitées par le plan choisi. Le seul avantage réel
    # apporté par le plan est le nombre de publications que l'éditeur
    # peut simultanément "mettre en avant" (meilleur classement dans les
    # listes publiques) — c'est un vrai plus, pas une fonctionnalité déjà
    # existante limitée après coup.
    max_priority_slots = models.PositiveIntegerField(
        default=0,
        help_text="Nombre de publications que l'éditeur peut mettre en avant simultanément"
    )

    # ─── 5 AUTRES AVANTAGES RÉELS, DISTINCTS PAR PLAN ──────────────────
    # Comme ci-dessus : ce sont de nouveaux avantages, jamais des
    # restrictions sur des fonctionnalités déjà existantes.
    commission_rate = models.DecimalField(
        max_digits=5, decimal_places=2, default=10.00,
        help_text="Taux de commission plateforme sur les ventes (%) — plus bas = l'éditeur garde plus d'argent"
    )
    max_reader_plans = models.PositiveIntegerField(
        default=3,
        help_text="Nombre d'offres d'abonnement (Lecteur→Éditeur) que l'éditeur peut créer (0 = illimité)"
    )
    has_verified_badge = models.BooleanField(
        default=False,
        help_text="Badge « Vérifié » affiché sur le profil public de l'éditeur"
    )
    min_withdrawal_amount = models.DecimalField(
        max_digits=10, decimal_places=2, default=10000,
        help_text="Montant minimum autorisé par demande de retrait — plus bas = plus de flexibilité"
    )
    max_withdrawal_amount = models.DecimalField(
        max_digits=10, decimal_places=2, default=500000,
        help_text="Montant maximum autorisé par demande de retrait — plus haut = plus de flexibilité"
    )
    has_stats_export = models.BooleanField(
        default=False,
        help_text="Autorise l'export CSV des statistiques détaillées"
    )

    # ─── SEUILS DE PROGRESSION AUTOMATIQUE (sans paiement) ─────────────
    # Un éditeur passe automatiquement à ce palier dès que TOUS ces
    # seuils sont atteints (voir apps.abonnements.services.sync_publisher_tier).
    # 0 = pas de condition sur ce critère (typiquement le palier "Basique").
    min_subscribers = models.PositiveIntegerField(
        default=0, help_text="Nombre d'abonnés requis pour atteindre ce palier"
    )
    min_publications = models.PositiveIntegerField(
        default=0, help_text="Nombre de publications requis pour atteindre ce palier"
    )
    min_sales = models.PositiveIntegerField(
        default=0, help_text="Nombre de ventes requis pour atteindre ce palier"
    )

    class Meta:
        verbose_name = _("Plan d'abonnement plateforme")
        verbose_name_plural = _("Plans d'abonnement plateforme")
        # Tri par seuils croissants (Basique -> Standard -> Premium) :
        # l'ancien tri par `prix` était devenu inutile — tous les paliers
        # sont gratuits (prix=0), l'ordre affiché était donc aléatoire.
        ordering = ['min_subscribers', 'min_publications', 'min_sales']

    def __str__(self):
        return f"{self.name} — {self.prix} FCFA/{self.period}"


class PublisherSubscription(models.Model):
    STATUS_CHOICES = [
        ('active', 'Actif'),
        ('expired', 'Expiré'),
        ('cancelled', 'Annulé'),
        ('pending', 'En attente'),
    ]

    publisher = models.ForeignKey(
        'accounts.User', on_delete=models.CASCADE,
        related_name='platform_subscriptions', limit_choices_to={'role': 'publisher'}
    )
    plan = models.ForeignKey(PlatformPlan, on_delete=models.SET_NULL, null=True, blank=True)
    montant = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    start_date = models.DateTimeField(null=True, blank=True)
    end_date = models.DateTimeField(null=True, blank=True)
    transaction_ref = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = _("Abonnement plateforme éditeur")
        verbose_name_plural = _("Abonnements plateforme éditeurs")
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.publisher.username} — plateforme ({self.status})"

    @property
    def is_active(self):
        if self.status != 'active':
            return False
        if self.end_date and timezone.now() > self.end_date:
            return False
        return True

    def activate(self, transaction_ref):
        from django.utils import timezone as tz
        from datetime import timedelta
        from apps.accounts.models import PublisherProfile
        from apps.notifications.models import Notification

        period_days = {'monthly': 30, 'quarterly': 90, 'yearly': 365}
        days = period_days.get(self.plan.period if self.plan else 'monthly', 30)

        self.status = 'active'
        self.start_date = tz.now()
        self.end_date = tz.now() + timedelta(days=days)
        self.transaction_ref = transaction_ref
        self.save()

        # C'est ici que l'accès à la plateforme est réellement débloqué.
        profile, _ = PublisherProfile.objects.get_or_create(
            user=self.publisher,
            defaults={'company_name': self.publisher.name or self.publisher.username}
        )
        profile.is_active = True
        profile.save(update_fields=['is_active'])

        Notification.objects.create(
            user=self.publisher,
            type_notif='subscription_activated',
            title="Abonnement plateforme activé !",
            message=f"Votre abonnement plateforme est actif jusqu'au {self.end_date.strftime('%d/%m/%Y')}. Vous avez maintenant accès à toutes les fonctionnalités éditeur."
        )
