from django.db import models
from apps.accounts.models import User

class Publication(models.Model):
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    publisher = models.ForeignKey(User, on_delete=models.CASCADE, related_name='publications')
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.title
