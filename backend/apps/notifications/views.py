import logging

from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import Notification, FCMToken
from .serializers import NotificationSerializer, FCMTokenSerializer

logger = logging.getLogger('apps')


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


class NotificationDeleteView(APIView):
    """Supprime une notification (DELETE) ou toutes les notifications de
    l'utilisateur connecté (DELETE /notifications/ sans pk). Le compteur
    non-lu est recalculé automatiquement au prochain GET.
    """
    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request, pk=None):
        if pk:
            Notification.objects.filter(pk=pk, user=request.user).delete()
            return Response({'message': 'Notification supprimée.'})
        Notification.objects.filter(user=request.user).delete()
        return Response({'message': 'Toutes les notifications ont été supprimées.'})


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
import json
import requests
from django.conf import settings

_fcm_access_token_cache = {'token': None, 'expiry': 0}


def _get_fcm_access_token():
    """Génère (et met en cache) un token OAuth2 pour l'API FCM HTTP v1.

    Utilise un compte de service Firebase. Cherche le JSON soit dans un
    fichier (FIREBASE_SERVICE_ACCOUNT_JSON_PATH), soit directement dans une
    variable d'environnement (FIREBASE_SERVICE_ACCOUNT_JSON) — pratique sur
    Render où déposer un fichier est moins pratique qu'une env var.
    """
    import time
    if _fcm_access_token_cache['token'] and _fcm_access_token_cache['expiry'] > time.time() + 60:
        return _fcm_access_token_cache['token']

    try:
        from google.oauth2 import service_account
        from google.auth.transport.requests import Request as GoogleAuthRequest
    except ImportError:
        logger.warning("Le paquet 'google-auth' n'est pas installé (voir requirements.txt).")
        return None

    raw_json = os.environ.get('FIREBASE_SERVICE_ACCOUNT_JSON')
    json_path = os.environ.get('FIREBASE_SERVICE_ACCOUNT_JSON_PATH')

    try:
        if raw_json:
            info = json.loads(raw_json)
            credentials = service_account.Credentials.from_service_account_info(
                info, scopes=['https://www.googleapis.com/auth/firebase.messaging'],
            )
        elif json_path and os.path.exists(json_path):
            credentials = service_account.Credentials.from_service_account_file(
                json_path, scopes=['https://www.googleapis.com/auth/firebase.messaging'],
            )
        else:
            return None

        credentials.refresh(GoogleAuthRequest())
        _fcm_access_token_cache['token'] = credentials.token
        _fcm_access_token_cache['expiry'] = credentials.expiry.timestamp() if credentials.expiry else time.time() + 3000
        return credentials.token
    except Exception:
        logger.exception("Impossible de générer le token OAuth2 FCM.")
        return None


def send_fcm_push(user, title, message, data=None):
    """Envoie une notification push via Firebase Cloud Messaging (API HTTP v1).

    L'ancienne API legacy ('fcm.googleapis.com/fcm/send', auth par clé
    serveur) a été définitivement coupée par Google en juin 2024. Cette
    fonction utilise désormais l'API HTTP v1 (OAuth2 + compte de service),
    la seule encore supportée. Configuration requise (variables d'env) :
    - FIREBASE_SERVICE_ACCOUNT_JSON : contenu JSON du compte de service, OU
    - FIREBASE_SERVICE_ACCOUNT_JSON_PATH : chemin vers ce fichier JSON.
    Tant qu'aucune des deux n'est configurée, la fonction ne fait rien
    (log un avertissement) — comportement volontairement silencieux pour ne
    jamais casser le reste du flux (paiement, avertissement, etc.) qui
    déclenche cette notification.
    """
    tokens = list(user.fcm_tokens.values_list('token', flat=True))
    if not tokens:
        return

    access_token = _get_fcm_access_token()
    if not access_token:
        logger.warning(
            "FCM non configuré (FIREBASE_SERVICE_ACCOUNT_JSON[_PATH] absent). "
            "Notification push non envoyée à %s.", user.username,
        )
        return

    project_id = getattr(settings, 'FIREBASE_PROJECT_ID', 'digitalpress-ec022')
    url = f'https://fcm.googleapis.com/v1/projects/{project_id}/messages:send'
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json; UTF-8',
    }
    # L'API v1 exige des chaînes pour toutes les valeurs de 'data'.
    str_data = {str(k): str(v) for k, v in (data or {}).items()}

    success, failures = 0, 0
    for token in tokens:
        payload = {
            'message': {
                'token': token,
                'notification': {'title': title, 'body': message},
                'data': str_data,
                'android': {'priority': 'high'},
                'apns': {'payload': {'aps': {'sound': 'default', 'badge': 1}}},
            }
        }
        try:
            response = requests.post(url, json=payload, headers=headers, timeout=10)
            if response.status_code == 200:
                success += 1
            else:
                failures += 1
                logger.warning(
                    "Erreur d'envoi FCM v1 pour %s : %s - %s",
                    user.username, response.status_code, response.text,
                )
        except Exception:
            failures += 1
            logger.exception("Erreur d'envoi push FCM v1 pour %s", user.username)

    if success:
        logger.info("Notification FCM v1 envoyée à %s (%d/%d tokens)", user.username, success, len(tokens))


def send_notification(user, type_notif, title, message, data=None):
    """Crée une notification en base.

    La diffusion WebSocket ET l'envoi FCM sont désormais centralisés dans
    le signal post_save de Notification (signals.py) : toute notification
    créée ici — ou directement via Notification.objects.create() ailleurs
    — est poussée en temps réel (WebSocket) et en push système (FCM) sans
    duplication.
    """
    return Notification.objects.create(
        user=user, type_notif=type_notif, title=title,
        message=message, data=data or {}
    )
