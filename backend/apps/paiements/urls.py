from django.urls import path
from .views import (
    InitierPaiementView, VerifierPaiementView, WebhookView,
    MesTransactionsView, AdminTransactionsView,
    DemanderRetraitView, MesDemandesRetraitView,
    AdminDemandesRetraitView, AdminTraiterRetraitView,
)

urlpatterns = [
    path('initier/', InitierPaiementView.as_view(), name='initier_paiement'),
    path('verifier/', VerifierPaiementView.as_view(), name='verifier_paiement'),
    path('webhook/', WebhookView.as_view(), name='webhook'),
    path('transactions/', MesTransactionsView.as_view(), name='mes_transactions'),
    path('admin/transactions/', AdminTransactionsView.as_view(), name='admin_transactions'),
    path('retrait/demander/', DemanderRetraitView.as_view(), name='demander_retrait'),
    path('retrait/mes-demandes/', MesDemandesRetraitView.as_view(), name='mes_demandes_retrait'),
    path('admin/retraits/', AdminDemandesRetraitView.as_view(), name='admin_retraits'),
    path('admin/retraits/<int:pk>/traiter/', AdminTraiterRetraitView.as_view(), name='admin_traiter_retrait'),
]
