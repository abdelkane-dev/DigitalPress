from django.contrib import admin
from .models import EcritureComptable, ReconciliationComptable


@admin.register(EcritureComptable)
class EcritureComptableAdmin(admin.ModelAdmin):
    list_display = ['reference', 'type_ecriture', 'libelle', 'montant',
                    'compte_debit', 'compte_credit', 'periode_mois',
                    'periode_annee', 'is_reconciled', 'created_at']
    list_filter = ['type_ecriture', 'is_reconciled', 'devise', 'periode_annee']
    search_fields = ['reference', 'libelle', 'editeur__username', 'client__username']
    readonly_fields = ['reference', 'created_at']
    date_hierarchy = 'date_ecriture'


@admin.register(ReconciliationComptable)
class ReconciliationComptableAdmin(admin.ModelAdmin):
    list_display = ['periode_mois', 'periode_annee', 'total_recettes',
                    'total_commissions', 'ecart', 'status', 'reconciled_at']
    list_filter = ['status', 'periode_annee']
    readonly_fields = ['created_at', 'updated_at']
