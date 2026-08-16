from django.db import models
from django.utils.translation import gettext_lazy as _
from django.utils.text import slugify


class Category(models.Model):
    name = models.CharField(max_length=100, unique=True)
    slug = models.SlugField(unique=True, blank=True)
    description = models.TextField(blank=True)
    icon = models.CharField(max_length=50, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def save(self, *args, **kwargs):
        if not self.slug and self.name:
            base_slug = slugify(self.name)
            slug = base_slug
            counter = 1
            while Category.objects.filter(slug=slug).exclude(pk=self.pk).exists():
                slug = f"{base_slug}-{counter}"
                counter += 1
            self.slug = slug
        super().save(*args, **kwargs)

    class Meta:
        verbose_name = _('Catégorie')
        verbose_name_plural = _('Catégories')
        ordering = ['name']

    def __str__(self):
        return self.name


class Publication(models.Model):
    STATUS_CHOICES = [
        ('draft', 'Brouillon'),
        ('published', 'Publié'),
        ('archived', 'Archivé'),
    ]
    TYPE_CHOICES = [
        ('article', 'Article'),
        ('magazine', 'Magazine'),
        ('journal', 'Journal'),
        ('report', 'Rapport'),
        ('ebook', 'E-book'),
    ]

    title = models.CharField(max_length=500)
    description = models.TextField()
    content = models.TextField(blank=True)
    publisher = models.ForeignKey(
        'accounts.User', on_delete=models.CASCADE, related_name='publications'
    )
    category = models.ForeignKey(
        Category, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='publications'
    )
    cover_image = models.URLField(blank=True)
    file_url = models.URLField(blank=True)
    video_url = models.URLField(blank=True)
    prix = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    resell_price = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True, help_text="Prix pour l'achat des droits de revente par un autre média")
    original_publication = models.ForeignKey('self', on_delete=models.SET_NULL, null=True, blank=True, related_name='resold_versions')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='published')
    pub_type = models.CharField(max_length=20, choices=TYPE_CHOICES, default='article')
    is_free = models.BooleanField(default=False)
    is_subscriber_exclusive = models.BooleanField(
        default=False,
        help_text="Réservé exclusivement aux lecteurs abonnés à cet éditeur — "
                   "non achetable à l'unité, contrairement au contenu payant "
                   "normal (voir Publication.is_accessible_by)."
    )
    views_count = models.PositiveIntegerField(default=0)
    is_featured = models.BooleanField(
        default=False,
        help_text="Mise en avant dans les listes publiques — avantage réel selon le plan plateforme de l'éditeur"
    )
    downloads_count = models.PositiveIntegerField(default=0)
    tags = models.CharField(max_length=500, blank=True, help_text='Tags séparés par des virgules')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = _('Publication')
        verbose_name_plural = _('Publications')
        ordering = ['-created_at']

    def __str__(self):
        return self.title

    @property
    def tags_list(self):
        return [t.strip() for t in self.tags.split(',') if t.strip()]

    def is_accessible_by(self, user):
        """Source UNIQUE de la règle d'accès au contenu complet d'une
        publication — remplace les deux implémentations qui existaient en
        double (PublicationSerializer._has_full_access et
        PublicationFileDownloadView._has_full_access), désormais réduites à
        un simple appel à cette méthode.

        Contenu "réservé aux abonnés" (is_subscriber_exclusive=True) : ne
        peut JAMAIS être débloqué par un achat à l'unité, même si `prix` ou
        `is_free` le permettraient normalement — seul un abonnement actif à
        l'éditeur donne accès, exactement comme un contenu promotionnel
        propre à chaque éditeur.
        """
        if not user or not getattr(user, 'is_authenticated', False):
            return False
        if user == self.publisher or getattr(user, 'role', None) == 'admin':
            return True

        from apps.abonnements.models import Abonnement
        from django.utils import timezone
        from django.db.models import Q

        now = timezone.now()
        has_active_subscription = Abonnement.objects.filter(
            reader=user, status='active', end_date__gt=now
        ).filter(Q(publication=self) | Q(publisher=self.publisher)).exists()

        if self.is_subscriber_exclusive:
            return has_active_subscription
        if self.is_free or self.prix == 0:
            return True
        if has_active_subscription:
            return True

        from apps.paiements.models import Transaction
        return Transaction.objects.filter(
            payer=user, publication=self, type_transaction='purchase', status='success'
        ).exists()


class Review(models.Model):
    publication = models.ForeignKey(
        Publication, on_delete=models.CASCADE, related_name='reviews'
    )
    reader = models.ForeignKey(
        'accounts.User', on_delete=models.CASCADE, related_name='reviews'
    )
    rating = models.PositiveSmallIntegerField(default=5)
    comment = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = _('Avis')
        verbose_name_plural = _('Avis')
        unique_together = ['publication', 'reader']

    def __str__(self):
        return f"{self.reader.username} → {self.publication.title} ({self.rating}/5)"


class Comment(models.Model):
    """Réponse "façon Facebook" dans la conversation d'un article.

    Le premier message d'un utilisateur dans une conversation est toujours
    son avis noté par étoiles (modèle `Review`, un seul par utilisateur).
    Une fois cet avis posté, l'utilisateur peut échanger librement avec les
    autres via des `Comment` : plusieurs messages, réponses à n'importe qui
    (via `parent`), sans limite.
    """
    publication = models.ForeignKey(
        Publication, on_delete=models.CASCADE, related_name='comments'
    )
    author = models.ForeignKey(
        'accounts.User', on_delete=models.CASCADE, related_name='publication_comments'
    )
    text = models.TextField()
    parent = models.ForeignKey(
        'self', on_delete=models.CASCADE, null=True, blank=True, related_name='replies'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = _('Commentaire')
        verbose_name_plural = _('Commentaires')
        ordering = ['created_at']

    def __str__(self):
        return f"{self.author.username} sur {self.publication.title} : {self.text[:40]}"


class ConversationRead(models.Model):
    """Mémorise la dernière consultation, par un utilisateur, de la section
    commentaires d'un article. Sert à calculer les badges "nouveaux
    commentaires non lus" de la page "Mes Conversations".
    """
    user = models.ForeignKey(
        'accounts.User', on_delete=models.CASCADE, related_name='conversation_reads'
    )
    publication = models.ForeignKey(
        Publication, on_delete=models.CASCADE, related_name='conversation_reads'
    )
    last_read_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = _('Lecture de conversation')
        verbose_name_plural = _('Lectures de conversations')
        unique_together = ['user', 'publication']

    def __str__(self):
        return f"{self.user.username} a lu {self.publication.title} le {self.last_read_at}"


class HiddenConversation(models.Model):
    """Permet à un utilisateur de "quitter" une conversation : l'article est
    simplement masqué de sa page "Mes Conversations", sans supprimer ses
    commentaires ni ceux des autres.
    """
    user = models.ForeignKey(
        'accounts.User', on_delete=models.CASCADE, related_name='hidden_conversations'
    )
    publication = models.ForeignKey(
        Publication, on_delete=models.CASCADE, related_name='hidden_by'
    )
    hidden_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = _('Conversation masquée')
        verbose_name_plural = _('Conversations masquées')
        unique_together = ['user', 'publication']

    def __str__(self):
        return f"{self.user.username} a quitté la conversation de {self.publication.title}"


class ReaderCategory(models.Model):
    """Catégorie personnelle créée par un Lecteur pour organiser ses
    favoris, comme une playlist YouTube. Strictement personnelle : n'a
    aucun rapport avec le modèle `Category` global (admin/éditeur) et
    n'est visible que par son créateur.
    """
    reader = models.ForeignKey(
        'accounts.User', on_delete=models.CASCADE, related_name='reader_categories'
    )
    name = models.CharField(max_length=100)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = _('Catégorie personnelle (Lecteur)')
        verbose_name_plural = _('Catégories personnelles (Lecteur)')
        unique_together = ['reader', 'name']
        ordering = ['name']

    def __str__(self):
        return f"{self.name} ({self.reader.username})"


class Favorite(models.Model):
    """Article mis en favori par un Lecteur, éventuellement rangé dans une
    ou plusieurs de ses catégories personnelles (playlists).
    """
    reader = models.ForeignKey(
        'accounts.User', on_delete=models.CASCADE, related_name='favorites'
    )
    publication = models.ForeignKey(
        Publication, on_delete=models.CASCADE, related_name='favorited_by'
    )
    categories = models.ManyToManyField(
        ReaderCategory, blank=True, related_name='favorites'
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = _('Favori')
        verbose_name_plural = _('Favoris')
        unique_together = ['reader', 'publication']
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.reader.username} ♥ {self.publication.title}"


class PublicationView(models.Model):
    """Trace chaque vue réellement comptée d'une publication (dédupliquée à
    30 min par visiteur dans PublicationDetailView._register_view_once).

    Sert au calcul de la section « À la une » de l'accueil : les
    publications qui accumulent un nombre impressionnant de vues en peu de
    temps (ex: vues des 48 dernières heures) sont automatiquement mises en
    avant côté « Tendances », indépendamment de la mise en avant payante.
    """
    publication = models.ForeignKey(
        Publication, on_delete=models.CASCADE, related_name='view_events'
    )
    viewer_key = models.CharField(max_length=100)
    viewed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = _('Vue de publication')
        verbose_name_plural = _('Vues de publications')
        ordering = ['-viewed_at']
        indexes = [
            models.Index(fields=['publication', 'viewed_at']),
        ]

    def __str__(self):
        return f"{self.publication.title} — {self.viewer_key} — {self.viewed_at}"


class FeaturedPromotion(models.Model):
    """Mise en avant payante d'une publication (« À la une »), façon publicité
    Facebook : l'éditeur paie pour mettre sa publication en avant sur
    l'accueil pendant une durée définie (7, 14 ou 30 jours).

    Tant que la promotion est active, `Publication.is_featured` reste True
    (la liste publique est triée avec -is_featured en tête). Une tâche
    Celery quotidienne (expirer_mises_en_avant) repasse is_featured à False
    dès que la promotion expire.
    """
    STATUS_CHOICES = [
        ('pending', 'En attente de paiement'),
        ('active', 'Active'),
        ('expired', 'Expirée'),
        ('cancelled', 'Annulée'),
    ]

    publication = models.ForeignKey(
        Publication, on_delete=models.CASCADE, related_name='featured_promotions'
    )
    publisher = models.ForeignKey(
        'accounts.User', on_delete=models.CASCADE, related_name='featured_promotions'
    )
    duration_days = models.PositiveIntegerField(default=7)
    montant = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    starts_at = models.DateTimeField(null=True, blank=True)
    ends_at = models.DateTimeField(null=True, blank=True)
    transaction = models.ForeignKey(
        'paiements.Transaction', on_delete=models.SET_NULL, null=True, blank=True
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = _('Mise en avant payante')
        verbose_name_plural = _('Mises en avant payantes')
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.publication.title} — {self.duration_days}j — {self.status}"


class CollaborationRight(models.Model):
    buyer_publisher = models.ForeignKey(
        'accounts.User', on_delete=models.CASCADE, related_name='collaboration_rights_bought', limit_choices_to={'role': 'publisher'}
    )
    original_publication = models.ForeignKey(
        Publication, on_delete=models.CASCADE, related_name='collaboration_rights_sold'
    )
    price_paid = models.DecimalField(max_digits=10, decimal_places=2)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = _('Droit de collaboration')
        verbose_name_plural = _('Droits de collaboration')
        unique_together = ['buyer_publisher', 'original_publication']

    def __str__(self):
        return f"{self.buyer_publisher.username} - Droit sur {self.original_publication.title}"
