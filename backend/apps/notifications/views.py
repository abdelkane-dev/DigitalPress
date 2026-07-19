from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import Notification, FCMToken
from .serializers import NotificationSerializer, FCMTokenSerializer


class NotificationListView(generics.ListAPIView):
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(user=self.request.user).order_by('-created_at')


class NotificationMarkReadView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk=None):
        if pk:
            Notification.objects.filter(pk=pk, user=request.user).update(is_read=True)
        else:
            Notification.objects.filter(user=request.user, is_read=False).update(is_read=True)
        return Response({'message': 'Notifications marquées comme lues.'})


class NotificationCountView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        unread = Notification.objects.filter(user=request.user, is_read=False).count()
        return Response({'unread_count': unread})


class RegisterFCMTokenView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        token = request.data.get('token')
        device_type = request.data.get('device_type', 'android')
        if not token:
            return Response({'error': 'Token FCM manquant.'}, status=400)
        FCMToken.objects.update_or_create(
            token=token,
            defaults={'user': request.user, 'device_type': device_type}
        )
        return Response({'message': 'Token FCM enregistré.'})


import os
import requests
from django.conf import settings

def send_fcm_push(user, title, message, data=None):
    """Envoie une notification push via Firebase Cloud Messaging."""
    tokens = list(user.fcm_tokens.values_list('token', flat=True))
    if not tokens:
        return

    server_key = getattr(settings, 'FIREBASE_SERVER_KEY', None)
    if not server_key:
        server_key = os.environ.get('FIREBASE_SERVER_KEY')

    if not server_key:
        print("FCM Server Key non configurée. Impossible d'envoyer la notification push.")
        return

    headers = {
        'Authorization': f'key={server_key}',
        'Content-Type': 'application/json',
    }

    payload = {
        'registration_ids': tokens,
        'notification': {
            'title': title,
            'body': message,
            'sound': 'default',
            'badge': 1,
        },
        'data': data or {},
    }

    try:
        response = requests.post('https://fcm.googleapis.com/fcm/send', json=payload, headers=headers)
        if response.status_code == 200:
            print(f"Notification FCM envoyée avec succès à {user.username}")
        else:
            print(f"Erreur d'envoi FCM : {response.status_code} - {response.text}")
    except Exception as e:
        print(f"Erreur d'envoi push FCM : {e}")


def send_notification(user, type_notif, title, message, data=None):
    """Crée une notification en base et tente l'envoi FCM."""
    notif = Notification.objects.create(
        user=user, type_notif=type_notif, title=title,
        message=message, data=data or {}
    )
    send_fcm_push(user, title, message, data)
    return notif
