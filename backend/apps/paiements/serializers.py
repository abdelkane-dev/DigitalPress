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
    publisher_subscription_id = serializers.IntegerField(required=False)
    montant = serializers.DecimalField(max_digits=12, decimal_places=2, required=False)
    phone = serializers.CharField(max_length=20, required=False, allow_blank=True)
    # ─── DROITS DE REVENTE SUPPRIMÉS : 'resell_right' n'est plus accepté
    # (demande explicite — l'accès se fait uniquement par achat ou abonnement).
    type_transaction = serializers.ChoiceField(
        choices=['subscription', 'platform_subscription', 'purchase', 'recharge'], default='purchase'
    )
    # Moyen de paiement choisi côté app : 'wallet' (portefeuille interne),
    # 'mobile_money' (Wave/Orange/Moov/Sama via CinetPay), 'card' (carte
    # bancaire via CinetPay), 'cinetpay'/'all' (tous les canaux CinetPay).
    mode_paiement = serializers.CharField(max_length=50, default='cinetpay')
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
    mode_paiement = serializers.CharField(required=False, allow_blank=True, default='mobile_money')
    numero_compte = serializers.CharField(required=False, allow_blank=True, default='')
    # ─── CONFIRMATION OTP (protection des retraits frauduleux) ───────────
    # Avant de créer une demande de retrait, le titulaire du compte doit
    # fournir le code à 6 chiffres reçu par email/SMS (voir
    # WithdrawalVerificationCode / WithdrawalOtpView). Sans code valide, la
    # demande est refusée : un fraudeur qui aurait pris le contrôle de la
    # session ne peut pas vider le solde sans accéder aussi à la boîte
    # mail / au téléphone du titulaire.
    otp_code = serializers.CharField(min_length=6, max_length=6, write_only=True)

    class Meta:
        model = DemandeRetrait
        fields = ['montant', 'mode_paiement', 'numero_compte', 'otp_code']

    def validate(self, attrs):
        attrs = super().validate(attrs)
        user = self.context['request'].user
        otp_code = (attrs.pop('otp_code', '') or '').strip()
        if not otp_code:
            raise serializers.ValidationError(
                {'otp_code': 'Un code de confirmation est requis pour valider la demande de retrait.'}
            )

        from .models import WithdrawalVerificationCode
        verification = WithdrawalVerificationCode.objects.filter(
            user=user, is_used=False
        ).order_by('-created_at').first()
        if not verification or not verification.is_valid():
            raise serializers.ValidationError(
                {'otp_code': 'Code invalide ou expiré. Demandez un nouveau code.'}
            )
        if verification.code_hash != WithdrawalVerificationCode.hash_code(otp_code):
            verification.attempts += 1
            verification.save(update_fields=['attempts'])
            raise serializers.ValidationError(
                {'otp_code': 'Code invalide ou expiré. Demandez un nouveau code.'}
            )
        # Le code est consommé : il ne peut servir qu'à UNE demande.
        verification.is_used = True
        verification.save(update_fields=['is_used'])
        WithdrawalVerificationCode.objects.filter(user=user, is_used=False).update(is_used=True)
        return attrs

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
            # En cas de profil éditeur absent, on cherche un solde sur l'utilisateur
            balance = getattr(user, 'solde', None)
            if balance is None:
                raise serializers.ValidationError("Profil éditeur introuvable.")
            if value > balance:
                raise serializers.ValidationError(
                    f"Solde insuffisant. Disponible: {balance} FCFA"
                )
            return value

        if value > profile.solde:
            raise serializers.ValidationError(
                f"Solde insuffisant. Disponible: {profile.solde} FCFA"
            )

        # ─── AVANTAGE RÉEL DU PLAN : MONTANT MIN/MAX DE RETRAIT ────────────
        active_sub = user.platform_subscriptions.filter(
            status='active'
        ).select_related('plan').first()
        min_amount = active_sub.plan.min_withdrawal_amount if (active_sub and active_sub.plan) else 10000
        max_amount = active_sub.plan.max_withdrawal_amount if (active_sub and active_sub.plan) else 500000
        if value < min_amount:
            raise serializers.ValidationError(
                f"Le montant minimum de retrait pour votre plan est de {min_amount} FCFA."
            )
        if value > max_amount:
            raise serializers.ValidationError(
                f"Le montant maximum de retrait pour votre plan est de {max_amount} FCFA par demande. "
                f"Passez à un plan supérieur pour retirer davantage en une fois, ou faites plusieurs demandes."
            )
        return value

    def create(self, validated_data):
        validated_data['editeur'] = self.context['request'].user
        return super().create(validated_data)


class AdminTraiterRetraitSerializer(serializers.Serializer):
    action = serializers.ChoiceField(choices=['approve', 'reject', 'complete'])
    motif_rejet = serializers.CharField(required=False, allow_blank=True)
    notes_admin = serializers.CharField(required=False, allow_blank=True)
