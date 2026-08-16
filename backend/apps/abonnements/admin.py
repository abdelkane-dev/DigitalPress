from django.contrib import admin
from .models import Plan, Abonnement, PlatformPlan, PublisherSubscription


@admin.register(Plan)
class PlanAdmin(admin.ModelAdmin):
    list_display = ['name', 'prix', 'period', 'max_publications', 'is_active']
    list_filter = ['period', 'is_active']


@admin.register(Abonnement)
class AbonnementAdmin(admin.ModelAdmin):
    list_display = ['reader', 'publication', 'plan', 'montant', 'status', 'start_date', 'end_date']
    list_filter = ['status', 'auto_renew']
    search_fields = ['reader__username', 'publication__title']
    readonly_fields = ['created_at', 'updated_at']


@admin.register(PlatformPlan)
class PlatformPlanAdmin(admin.ModelAdmin):
    list_display = ['name', 'prix', 'period', 'is_active']
    list_filter = ['period', 'is_active']


@admin.register(PublisherSubscription)
class PublisherSubscriptionAdmin(admin.ModelAdmin):
    list_display = ['publisher', 'plan', 'montant', 'status', 'start_date', 'end_date']
    list_filter = ['status']
    search_fields = ['publisher__username']
    readonly_fields = ['created_at', 'updated_at']
