from rest_framework import serializers
from .models import EcritureComptable, ReconciliationComptable


class EcritureComptableSerializer(serializers.ModelSerializer):
    type_ecriture_display = serializers.CharField(source='get_type_ecriture_display', read_only=True)
    editeur_username = serializers.CharField(source='editeur.username', read_only=True)
    client_username = serializers.CharField(source='client.username', read_only=True)
    publication_title = serializers.CharField(source='publication.title', read_only=True)
    transaction_ref = serializers.CharField(source='transaction.reference', read_only=True)

    class Meta:
        model = EcritureComptable
        fields = [
            'id', 'reference', 'transaction', 'transaction_ref',
            'date_ecriture', 'type_ecriture', 'type_ecriture_display',
            'compte_debit', 'compte_credit', 'libelle',
            'montant', 'montant_commission',
            'editeur', 'editeur_username', 'client', 'client_username',
            'publication', 'publication_title',
            'devise', 'periode_mois', 'periode_annee',
            'is_reconciled', 'notes', 'created_at',
        ]
        read_only_fields = ['reference', 'created_at']


class ReconciliationComptableSerializer(serializers.ModelSerializer):
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    reconciled_by_username = serializers.CharField(source='reconciled_by.username', read_only=True)

    class Meta:
        model = ReconciliationComptable
        fields = [
            'id', 'periode_mois', 'periode_annee',
            'total_recettes', 'total_commissions', 'total_retraits', 'total_remboursements',
            'solde_theorique', 'solde_reel', 'ecart',
            'nb_transactions', 'nb_ecritures',
            'status', 'status_display', 'notes',
            'reconciled_by', 'reconciled_by_username', 'reconciled_at',
            'created_at', 'updated_at',
        ]
        read_only_fields = [
            'total_recettes', 'total_commissions', 'total_retraits', 'total_remboursements',
            'solde_theorique', 'solde_reel', 'ecart',
            'nb_transactions', 'nb_ecritures', 'reconciled_by', 'reconciled_at',
            'created_at', 'updated_at',
        ]
