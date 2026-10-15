from django.urls import path
from .views import (
    NotificationListView, NotificationMarkReadView, NotificationDeleteView,
    NotificationCountView, RegisterFCMTokenView,
)

urlpatterns = [
    path('', NotificationListView.as_view(), name='notifications'),
    path('delete-all/', NotificationDeleteView.as_view(), name='delete_all'),
    path('count/', NotificationCountView.as_view(), name='notification_count'),
    path('mark-read/', NotificationMarkReadView.as_view(), name='mark_all_read'),
    path('<int:pk>/mark-read/', NotificationMarkReadView.as_view(), name='mark_read'),
    path('<int:pk>/', NotificationDeleteView.as_view(), name='notification_delete'),
    path('fcm/register/', RegisterFCMTokenView.as_view(), name='register_fcm'),
]
