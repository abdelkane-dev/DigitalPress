from rest_framework import serializers
from .models import Transaction, DemandeRetrait


class TransactionSerializer(serializers.ModelSerializer):
    payer_username = serializers.CharField(source='payer.username', read_only=True)
    beneficiaire_username = serializers.CharField(source='beneficiaire.username', read_only=True)
    publication_title = serializers.CharField(source='publication.title', read_only=True)

    class Meta:
        model = Transaction
        fields = [
            'id', 'reference', 'movapay_ref', 'payer', 'payer_username',
            'beneficiaire', 'beneficiaire_username', 'publication', 'publication_title',
            'abonnement', 'type_transaction', 'montant_brut', 'commission',
            'montant_net', 'devise', 'status', 'description', 'phone_payer',
            'metadata', 'created_at', 'processed_at',
        ]
        read_only_fields = ['reference', 'commission', 'montant_net', 'created_at', 'processed_at']


class InitierPaiementSerializer(serializers.Serializer):
    publication_id = serializers.IntegerField(required=False)
    abonnement_id = serializers.IntegerField(required=False)
    # Optionnel : uniquement pris en compte pour une recharge de portefeuille.
    # Pour un achat ou un abonnement, le montant réel est TOUJOURS recalculé
    # côté serveur à partir du prix enregistré en base (voir InitierPaiementView).
    montant = serializers.DecimalField(max_digits=10, decimal_places=2, required=False)
    phone = serializers.CharField(max_length=20, required=False, allow_blank=True)
    type_transaction = serializers.ChoiceField(
        choices=['subscription', 'purchase', 'recharge'], default='purchase'
    )
    mode_paiement = serializers.ChoiceField(
        choices=['movapay', 'wallet'], default='movapay'
    )
    description = serializers.CharField(max_length=500, required=False, allow_blank=True)


class VerifierPaiementSerializer(serializers.Serializer):
    reference = serializers.CharField()
    movapay_ref = serializers.CharField(required=False, allow_blank=True)


class DemandeRetraitSerializer(serializers.ModelSerializer):
    editeur_username = serializers.CharField(source='editeur.username', read_only=True)
    editeur_company = serializers.SerializerMethodField()
    traitee_par_username = serializers.CharField(source='traitee_par.username', read_only=True)

    class Meta:
        model = DemandeRetrait
        fields = [
            'id', 'editeur', 'editeur_username', 'editeur_company',
            'montant', 'mode_paiement', 'numero_compte',
            'status', 'motif_rejet', 'notes_admin',
            'traitee_par', 'traitee_par_username', 'transaction',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['editeur', 'status', 'traitee_par', 'transaction', 'created_at']

    def get_editeur_company(self, obj):
        if hasattr(obj.editeur, 'publisher_profile'):
            return obj.editeur.publisher_profile.company_name
        return ''


class DemandeRetraitCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = DemandeRetrait
        fields = ['montant', 'mode_paiement', 'numero_compte']

    def validate_montant(self, value):
        user = self.context['request'].user
        if value <= 0:
            raise serializers.ValidationError("Le montant doit être positif.")

        if user.role == 'admin':
            balance = getattr(user, 'solde', 0) or 0
            if value > balance:
                raise serializers.ValidationError(
                    f"Solde insuffisant. Disponible: {balance} FCFA"
                )
            return value

        profile = getattr(user, 'publisher_profile', None)
        if not profile:
            raise serializers.ValidationError("Profil éditeur introuvable.")
        if value > profile.solde:
            raise serializers.ValidationError(
                f"Solde insuffisant. Disponible: {profile.solde} FCFA"
            )
        return value

    def create(self, validated_data):
        validated_data['editeur'] = self.context['request'].user
        return super().create(validated_data)


class AdminTraiterRetraitSerializer(serializers.Serializer):
    action = serializers.ChoiceField(choices=['approve', 'reject', 'complete'])
    motif_rejet = serializers.CharField(required=False, allow_blank=True)
    notes_admin = serializers.CharField(required=False, allow_blank=True)
