from django.db import models
from django.contrib.auth.models import AbstractUser


class User(AbstractUser):
    ROLE_CHOICES = [
        ('reader', 'Reader'),
        ('publisher', 'Publisher'),
        ('admin', 'Admin'),
    ]

    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='reader')

    # Optional fields (can be empty for now)
    status = models.CharField(max_length=20, default='active')
    company_name = models.CharField(max_length=255, blank=True, null=True)   # for publisher/editor
    kyc_status = models.CharField(max_length=20, default='pending')          # pending/approved/rejected

    def __str__(self):
        return f"{self.username} ({self.role})"