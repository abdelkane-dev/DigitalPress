from django.contrib import admin
from .models import Plan, Abonnement


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
