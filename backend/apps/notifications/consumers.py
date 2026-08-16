"""Notifications en temps réel via WebSocket.

Chaque utilisateur connecté rejoint un groupe Channels qui porte son id
(`user_<id>`). Quand une Notification est créée n'importe où dans le
backend (paiement, vérification éditeur, commentaire, etc.), le signal
post_save (voir signals.py) pousse immédiatement le contenu à ce groupe —
donc à tous les onglets/appareils où cet utilisateur est connecté.

Design volontairement minimal : un seul canal ('notifications'), pas de
salons par conversation. C'est la première brique du temps réel demandée ;
les conversations/messages suivront le même schéma (un groupe par
conversation) dans une prochaine étape.
"""
import json

from channels.generic.websocket import AsyncWebsocketConsumer


class NotificationConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        user = self.scope.get('user')
        if not user or not user.is_authenticated:
            # Connexion refusée : pas de token valide fourni. Code 4001 =
            # code applicatif personnalisé (plage 4000-4999 réservée par la
            # RFC WebSocket aux usages applicatifs).
            await self.close(code=4001)
            return

        self.group_name = f'user_{user.id}'
        await self.channel_layer.group_add(self.group_name, self.channel_name)

        # Tous les admins rejoignent aussi un canal commun : certains
        # événements (nouvelle vérification éditeur, nouveau retrait à
        # traiter, nouvelle transaction...) doivent être vus par TOUS les
        # admins connectés en même temps, pas juste celui qui a déclenché
        # l'action.
        self.role = getattr(user, 'role', None)
        self.is_admin = self.role == 'admin'
        if self.is_admin:
            await self.channel_layer.group_add('admins', self.channel_name)

        # Roadmap fonctionnalités (voir apps.roadmap) : réservée à Admin +
        # Éditeur. Un Lecteur ne rejoint JAMAIS ce canal — séparation
        # stricte des rôles, même pour un événement sans donnée sensible.
        if self.role in ('admin', 'publisher'):
            await self.channel_layer.group_add('admins_and_publishers', self.channel_name)

        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, 'group_name'):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)
        if getattr(self, 'is_admin', False):
            await self.channel_layer.group_discard('admins', self.channel_name)
        if getattr(self, 'role', None) in ('admin', 'publisher'):
            await self.channel_layer.group_discard('admins_and_publishers', self.channel_name)

    async def receive(self, text_data=None, bytes_data=None):
        # Canal descendant uniquement (serveur -> client). On ignore tout
        # message entrant du client plutôt que de planter dessus.
        pass

    async def notify(self, event):
        """Appelé par le channel layer quand quelqu'un envoie un message au
        groupe (voir signals.py : group_send(..., {'type': 'notify', ...}))."""
        await self.send(text_data=json.dumps(event['payload']))


class SilentConsumer(AsyncWebsocketConsumer):
    """Consumer silencieux pour gérer proprement les connexions WS générées par
    les extensions de navigateur (ex: LiveReload / ws/live/) sans lever d'exception."""
    async def connect(self):
        await self.accept()

    async def disconnect(self, close_code):
        pass

    async def receive(self, text_data=None, bytes_data=None):
        pass
