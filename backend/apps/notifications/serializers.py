from rest_framework import serializers
from .models import Notification, FCMToken


class NotificationSerializer(serializers.ModelSerializer):
    type_notif_display = serializers.CharField(source='get_type_notif_display', read_only=True)

    class Meta:
        model = Notification
        fields = ['id', 'type_notif', 'type_notif_display', 'title', 'message',
                  'is_read', 'data', 'created_at']
        read_only_fields = ['created_at']


class FCMTokenSerializer(serializers.ModelSerializer):
    class Meta:
        model = FCMToken
        fields = ['id', 'token', 'device_type', 'created_at']
        read_only_fields = ['created_at']
