from django.contrib import admin
from .models import Transaction, DemandeRetrait


@admin.register(Transaction)
class TransactionAdmin(admin.ModelAdmin):
    list_display = ['reference', 'payer', 'beneficiaire', 'type_transaction',
                    'montant_brut', 'commission', 'montant_net', 'status', 'created_at']
    list_filter = ['status', 'type_transaction', 'devise']
    search_fields = ['reference', 'movapay_ref', 'payer__username', 'beneficiaire__username']
    readonly_fields = ['reference', 'created_at', 'updated_at', 'processed_at']


@admin.register(DemandeRetrait)
class DemandeRetraitAdmin(admin.ModelAdmin):
    list_display = ['editeur', 'montant', 'mode_paiement', 'status', 'created_at']
    list_filter = ['status', 'mode_paiement']
    search_fields = ['editeur__username']
    readonly_fields = ['created_at', 'updated_at']
