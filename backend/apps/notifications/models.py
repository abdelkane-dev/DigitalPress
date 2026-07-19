from django.db import models
from django.utils.translation import gettext_lazy as _


class Notification(models.Model):
    TYPE_CHOICES = [
        ('payment_success', 'Paiement réussi'),
        ('payment_failed', 'Paiement échoué'),
        ('subscription_activated', 'Abonnement activé'),
        ('subscription_expired', 'Abonnement expiré'),
        ('withdrawal_approved', 'Retrait approuvé'),
        ('withdrawal_rejected', 'Retrait rejeté'),
        ('withdrawal_completed', 'Retrait complété'),
        ('new_publication', 'Nouvelle publication'),
        ('new_comment', 'Nouveau commentaire'),
        ('new_reply', 'Nouvelle réponse'),
        ('system', 'Système'),
    ]

    user = models.ForeignKey(
        'accounts.User', on_delete=models.CASCADE, related_name='notifications'
    )
    type_notif = models.CharField(max_length=30, choices=TYPE_CHOICES, default='system')
    title = models.CharField(max_length=255)
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    data = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = _('Notification')
        verbose_name_plural = _('Notifications')
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.username} — {self.title}"


class FCMToken(models.Model):
    user = models.ForeignKey(
        'accounts.User', on_delete=models.CASCADE, related_name='fcm_tokens'
    )
    token = models.TextField(unique=True)
    device_type = models.CharField(max_length=20, default='android')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = _('Token FCM')
        verbose_name_plural = _('Tokens FCM')

    def __str__(self):
        return f"{self.user.username} — {self.device_type}"
