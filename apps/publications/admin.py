from django.contrib import admin
from .models import Publication, PublicationContent

class ContentInline(admin.StackedInline):
    model = PublicationContent
    extra = 1

@admin.register(Publication)
class PublicationAdmin(admin.ModelAdmin):
    list_display = ['title', 'editor', 'category', 'price', 'status']
    list_filter = ['status', 'format', 'category']
    inlines = [ContentInline]