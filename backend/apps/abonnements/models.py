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
