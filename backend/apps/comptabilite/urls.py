from django.urls import path
from .views import (
    AdminDashboardStatsView, AdminTopEditeursView, AdminEvolutionVentesView,
    AdminJournalComptableView, AdminJournalDetailView,
    AdminReconciliationView, AdminReconciliationDetailView,
    AdminExportJournalView, AdminExportTransactionsView,
    AdminSoldesEditeursView,
    EditeurJournalView, EditeurSoldeView,
    EditeurHistoriqueTransactionsView, EditeurExportView,
    EditeurStatsVentesView,
)

urlpatterns = [
    # ── Admin dashboard ───────────────────────────────────────
    path('admin/dashboard/stats/', AdminDashboardStatsView.as_view(), name='admin_dashboard_stats'),
    path('admin/dashboard/top-editeurs/', AdminTopEditeursView.as_view(), name='admin_top_editeurs'),
    path('admin/dashboard/evolution-ventes/', AdminEvolutionVentesView.as_view(), name='admin_evolution_ventes'),

    # ── Admin journal comptable ────────────────────────────────
    path('admin/comptabilite/journal/', AdminJournalComptableView.as_view(), name='admin_journal'),
    path('admin/comptabilite/journal/<int:pk>/', AdminJournalDetailView.as_view(), name='admin_journal_detail'),

    # ── Admin réconciliation ───────────────────────────────────
    path('admin/comptabilite/reconciliation/', AdminReconciliationView.as_view(), name='admin_reconciliation'),
    path('admin/comptabilite/reconciliation/<int:pk>/', AdminReconciliationDetailView.as_view(), name='admin_reconciliation_detail'),

    # ── Admin exports CSV ──────────────────────────────────────
    path('admin/comptabilite/export/', AdminExportJournalView.as_view(), name='admin_export_journal'),
    path('admin/comptabilite/export/transactions/', AdminExportTransactionsView.as_view(), name='admin_export_transactions'),

    # ── Admin soldes éditeurs ──────────────────────────────────
    path('admin/editeurs/soldes/', AdminSoldesEditeursView.as_view(), name='admin_soldes_editeurs'),

    # ── Éditeur ────────────────────────────────────────────────
    path('entreprise/comptabilite/journal/', EditeurJournalView.as_view(), name='editeur_journal'),
    path('entreprise/comptabilite/solde/', EditeurSoldeView.as_view(), name='editeur_solde'),
    path('entreprise/comptabilite/export/', EditeurExportView.as_view(), name='editeur_export'),
    path('entreprise/comptabilite/stats/', EditeurStatsVentesView.as_view(), name='editeur_stats'),
    path('entreprise/transactions/', EditeurHistoriqueTransactionsView.as_view(), name='editeur_transactions'),
]
