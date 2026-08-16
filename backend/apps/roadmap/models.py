from django.db import models
from django.utils.translation import gettext_lazy as _


class FeatureItem(models.Model):
    """Remplace, pour les rôles Admin et Éditeur, l'ancienne page "Catégories"
    (qui n'a de sens que pour le Lecteur). Cette page leur permet de suivre
    et proposer des fonctionnalités pas encore implémentées mais utiles pour
    la plateforme (roadmap produit interne).
    """

    STATUS_CHOICES = [
        ('a_venir', 'À venir'),
        ('en_cours', 'En cours de développement'),
        ('fait', 'Réalisé'),
        ('rejete', 'Non retenu'),
    ]
    SCOPE_CHOICES = [
        ('admin', 'Admin uniquement'),
        ('publisher', 'Éditeur uniquement'),
        ('both', 'Admin et Éditeur'),
    ]

    title = models.CharField(max_length=150)
    description = models.TextField(blank=True)
    scope = models.CharField(max_length=20, choices=SCOPE_CHOICES, default='both')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='a_venir')
    created_by = models.ForeignKey(
        'accounts.User', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='suggested_features'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = _('Fonctionnalité à venir')
        verbose_name_plural = _('Fonctionnalités à venir')
        ordering = ['status', '-created_at']

    def __str__(self):
        return f"{self.title} ({self.get_status_display()})"
