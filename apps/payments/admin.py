from django.contrib import admin
from .models import Payment, Invoice

class InvoiceInline(admin.TabularInline):
    model = Invoice
    extra = 0
    readonly_fields = ['pdf_file', 'created_at']
    can_delete = False

@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    # Colonnes affichées dans la liste
    list_display = ['id', 'user', 'amount', 'status', 'payment_method', 'created_at']
    
    # Filtres sur le côté droit
    list_filter = ['status', 'payment_method', 'created_at']
    
    # Barre de recherche (par nom d'utilisateur ou ID de transaction)
    search_fields = ['user__username', 'id']
    
    # Permet de voir la facture liée directement dans le détail du paiement
    inlines = [InvoiceInline]
    
    # Configuration des couleurs pour le statut (facultatif mais pro)
    def get_status_display(self, obj):
        return obj.status
    get_status_display.short_description = 'Statut'

@admin.register(Invoice)
class InvoiceAdmin(admin.ModelAdmin):
    list_display = ['id', 'payment', 'created_at']
    readonly_fields = ['payment', 'pdf_file', 'created_at']