from rest_framework import serializers
from .models import FeatureItem


class FeatureItemSerializer(serializers.ModelSerializer):
    created_by_name = serializers.SerializerMethodField()
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    scope_display = serializers.CharField(source='get_scope_display', read_only=True)

    class Meta:
        model = FeatureItem
        fields = [
            'id', 'title', 'description', 'scope', 'scope_display', 'status',
            'status_display', 'created_by', 'created_by_name', 'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'created_by', 'created_at', 'updated_at']

    def get_created_by_name(self, obj):
        if not obj.created_by:
            return None
        return obj.created_by.name or obj.created_by.username


class FeatureItemStatusUpdateSerializer(serializers.ModelSerializer):
    """Utilisé par l'admin pour ne modifier que le statut d'avancement."""

    class Meta:
        model = FeatureItem
        fields = ['status']
