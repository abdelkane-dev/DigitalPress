from django.db import models
from django.conf import settings


class Publication(models.Model):
    FORMAT_CHOICES = [
        ('pdf', 'PDF'),
        ('epub', 'EPUB'),
        ('html', 'HTML'),
    ]

    STATUS_CHOICES = [
        ('draft', 'Draft'),
        ('published', 'Published'),
        ('archived', 'Archived'),
    ]

    editor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='publications'
    )

    title = models.CharField(max_length=255)
    category = models.CharField(max_length=100, blank=True)
    publication_date = models.DateField()
    price = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    format = models.CharField(max_length=10, choices=FORMAT_CHOICES, default='pdf')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='draft')

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.title} ({self.publication_date})"


class PublicationContent(models.Model):
    publication = models.OneToOneField(
        Publication,
        on_delete=models.CASCADE,
        related_name='content'
    )
    file = models.FileField(upload_to='publications/')
    encrypted = models.BooleanField(default=True)

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Content for {self.publication.title}"