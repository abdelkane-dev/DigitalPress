from rest_framework import serializers
from .models import Plan, Abonnement


class PlanSerializer(serializers.ModelSerializer):
    features_list = serializers.SerializerMethodField()
    publisher_name = serializers.SerializerMethodField()

    class Meta:
        model = Plan
        fields = ['id', 'name', 'publisher', 'publisher_name', 'description', 'prix', 'period',
                  'max_publications', 'features', 'features_list', 'is_active']
        read_only_fields = ['publisher']

    def get_publisher_name(self, obj):
        if not obj.publisher:
            return None
        if hasattr(obj.publisher, 'publisher_profile'):
            return obj.publisher.publisher_profile.company_name
        return obj.publisher.name or obj.publisher.username

    def get_features_list(self, obj):
        return [f.strip() for f in obj.features.split('\n') if f.strip()]


class AbonnementSerializer(serializers.ModelSerializer):
    reader_username = serializers.CharField(source='reader.username', read_only=True)
    publication_title = serializers.CharField(source='publication.title', read_only=True)
    plan_name = serializers.CharField(source='plan.name', read_only=True)
    publisher_name = serializers.SerializerMethodField()
    is_active = serializers.ReadOnlyField()

    class Meta:
        model = Abonnement
        fields = [
            'id', 'reader', 'reader_username', 'publication', 'publication_title',
            'plan', 'plan_name', 'publisher', 'publisher_name',
            'montant', 'status', 'start_date', 'end_date', 'auto_renew',
            'transaction_ref', 'is_active', 'created_at',
        ]
        read_only_fields = ['reader', 'status', 'start_date', 'transaction_ref', 'created_at']

    def get_publisher_name(self, obj):
        if obj.publisher:
            if hasattr(obj.publisher, 'publisher_profile'):
                return obj.publisher.publisher_profile.company_name
            return obj.publisher.name or obj.publisher.username
        return None


class AbonnementCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Abonnement
        fields = ['publication', 'plan', 'auto_renew']

    def validate(self, attrs):
        plan = attrs.get('plan')
        if not plan:
            raise serializers.ValidationError("Un plan d'abonnement est requis.")
        
        attrs['montant'] = plan.prix
        attrs['publisher'] = plan.publisher
        return attrs

    def create(self, validated_data):
        validated_data['reader'] = self.context['request'].user
        return super().create(validated_data)


class PublisherPlanCreateSerializer(serializers.ModelSerializer):
    """Permet à un éditeur de créer/modifier ses propres plans d'abonnement."""
    class Meta:
        model = Plan
        fields = ['id', 'name', 'description', 'prix', 'period', 'max_publications', 'features', 'is_active']

    def create(self, validated_data):
        validated_data['publisher'] = self.context['request'].user
        return super().create(validated_data)
