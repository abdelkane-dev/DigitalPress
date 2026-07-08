from django.contrib import admin
from .models import Publication, Category, Review


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ['name', 'slug']
    prepopulated_fields = {'slug': ('name',)}


@admin.register(Publication)
class PublicationAdmin(admin.ModelAdmin):
    list_display = ['title', 'publisher', 'category', 'prix', 'status', 'pub_type', 'views_count', 'created_at']
    list_filter = ['status', 'pub_type', 'is_free', 'category']
    search_fields = ['title', 'description', 'publisher__username']
    readonly_fields = ['views_count', 'downloads_count', 'created_at', 'updated_at']


@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    list_display = ['publication', 'reader', 'rating', 'created_at']
    list_filter = ['rating']
