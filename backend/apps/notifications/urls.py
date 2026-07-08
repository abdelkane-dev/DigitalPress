from django.urls import path
from .views import (
    NotificationListView, NotificationMarkReadView,
    NotificationCountView, RegisterFCMTokenView,
)

urlpatterns = [
    path('', NotificationListView.as_view(), name='notifications'),
    path('count/', NotificationCountView.as_view(), name='notification_count'),
    path('mark-read/', NotificationMarkReadView.as_view(), name='mark_all_read'),
    path('<int:pk>/mark-read/', NotificationMarkReadView.as_view(), name='mark_read'),
    path('fcm/register/', RegisterFCMTokenView.as_view(), name='register_fcm'),
]
