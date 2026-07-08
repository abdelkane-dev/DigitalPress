from django.contrib import admin
from .models import Notification, FCMToken


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ['user', 'type_notif', 'title', 'is_read', 'created_at']
    list_filter = ['type_notif', 'is_read']
    search_fields = ['user__username', 'title', 'message']


@admin.register(FCMToken)
class FCMTokenAdmin(admin.ModelAdmin):
    list_display = ['user', 'device_type', 'created_at']
    search_fields = ['user__username']
