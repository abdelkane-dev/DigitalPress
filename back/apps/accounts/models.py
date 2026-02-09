from django.contrib.auth.models import AbstractUser
from django.db import models

class User(AbstractUser):
    ROLE_CHOICES = (
        ('reader','Reader'),
        ('publisher','Publisher'),
        ('admin','Admin'),
    )
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='reader')
    name = models.CharField(max_length=150, blank=True)

    def __str__(self):
        return self.username

class PublisherProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='publisher_profile')
    company_name = models.CharField(max_length=255)

    def __str__(self):
        return self.company_name
