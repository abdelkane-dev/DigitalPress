from django.contrib import admin
from .models import (
    Publication, Category, Review, Comment, ConversationRead, HiddenConversation,
    ReaderCategory, Favorite, PublicationView, FeaturedPromotion,
)


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ['name', 'slug']
    prepopulated_fields = {'slug': ('name',)}


@admin.register(Publication)
class PublicationAdmin(admin.ModelAdmin):
    list_display = ['title', 'publisher', 'category', 'prix', 'status', 'pub_type', 'views_count', 'is_featured', 'created_at']
    list_filter = ['status', 'pub_type', 'is_free', 'is_featured', 'category']
    search_fields = ['title', 'description', 'publisher__username']
    readonly_fields = ['views_count', 'downloads_count', 'created_at', 'updated_at']


@admin.register(PublicationView)
class PublicationViewAdmin(admin.ModelAdmin):
    list_display = ['publication', 'viewer_key', 'viewed_at']
    list_filter = ['viewed_at']
    search_fields = ['publication__title', 'viewer_key']


@admin.register(FeaturedPromotion)
class FeaturedPromotionAdmin(admin.ModelAdmin):
    list_display = ['publication', 'publisher', 'duration_days', 'montant', 'status', 'starts_at', 'ends_at']
    list_filter = ['status']
    search_fields = ['publication__title', 'publisher__username']


@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    list_display = ['publication', 'reader', 'rating', 'created_at']
    list_filter = ['rating']


@admin.register(ConversationRead)
class ConversationReadAdmin(admin.ModelAdmin):
    list_display = ['user', 'publication', 'last_read_at']


@admin.register(HiddenConversation)
class HiddenConversationAdmin(admin.ModelAdmin):
    list_display = ['user', 'publication', 'hidden_at']


@admin.register(Comment)
class CommentAdmin(admin.ModelAdmin):
    list_display = ['author', 'publication', 'parent', 'created_at']
    search_fields = ['text', 'author__username', 'publication__title']


@admin.register(ReaderCategory)
class ReaderCategoryAdmin(admin.ModelAdmin):
    list_display = ['name', 'reader', 'created_at']


@admin.register(Favorite)
class FavoriteAdmin(admin.ModelAdmin):
    list_display = ['reader', 'publication', 'created_at']
    filter_horizontal = ['categories']
