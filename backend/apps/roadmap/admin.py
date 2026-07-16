from django.contrib import admin
from .models import FeatureItem


@admin.register(FeatureItem)
class FeatureItemAdmin(admin.ModelAdmin):
    list_display = ['title', 'scope', 'status', 'created_by', 'created_at']
    list_filter = ['scope', 'status']
    search_fields = ['title', 'description']
