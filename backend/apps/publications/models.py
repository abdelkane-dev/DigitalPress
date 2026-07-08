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
    prix = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='published')
    pub_type = models.CharField(max_length=20, choices=TYPE_CHOICES, default='article')
    is_free = models.BooleanField(default=False)
    views_count = models.PositiveIntegerField(default=0)
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

    class Meta:
        verbose_name = _('Avis')
        verbose_name_plural = _('Avis')
        unique_together = ['publication', 'reader']

    def __str__(self):
        return f"{self.reader.username} → {self.publication.title} ({self.rating}/5)"


class ConversationRead(models.Model):
    """Dernière lecture connue d'une conversation (par article et par utilisateur)."""
    user = models.ForeignKey('accounts.User', on_delete=models.CASCADE, related_name='conversation_reads')
    publication = models.ForeignKey(Publication, on_delete=models.CASCADE, related_name='conversation_reads')
    last_read_at = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ['user', 'publication']

    def __str__(self):
        return f"Read: {self.user.username} → {self.publication.title} @ {self.last_read_at}"


class HiddenConversation(models.Model):
    """Conversations masquées volontairement par l'utilisateur."""
    user = models.ForeignKey('accounts.User', on_delete=models.CASCADE, related_name='hidden_conversations')
    publication = models.ForeignKey(Publication, on_delete=models.CASCADE, related_name='hidden_by')
    hidden_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ['user', 'publication']

    def __str__(self):
        return f"Hidden: {self.user.username} → {self.publication.title}"
