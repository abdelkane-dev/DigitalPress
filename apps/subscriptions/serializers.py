from rest_framework import serializers
from .models import Subscription

class SubscriptionSerializer(serializers.ModelSerializer):
    # On ajoute un champ calculé pour savoir si l'abonnement est encore valide
    is_valid = serializers.SerializerMethodField()

    class Meta:
        model = Subscription
        fields = [
            'id', 'subscription_type', 'start_date', 'end_date', 
            'status', 'price', 'created_at', 'is_valid'
        ]

    def get_is_valid(self, obj):
        from django.utils import timezone
        return obj.status == 'active' and obj.end_date >= timezone.now().date()