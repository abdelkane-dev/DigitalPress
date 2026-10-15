"""Conversations (commentaires d'article) en temps réel via WebSocket.

Contrairement aux notifications (un groupe par UTILISATEUR), ici c'est un
groupe par ARTICLE : tout le monde qui regarde la conversation d'un même
article reçoit instantanément les nouveaux messages des autres, comme dans
une conversation de groupe classique (façon WhatsApp).
"""
import json

from channels.generic.websocket import AsyncWebsocketConsumer


class ConversationConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        user = self.scope.get('user')
        if not user or not user.is_authenticated:
            await self.close(code=4001)
            return

        publication_id = self.scope['url_route']['kwargs']['publication_id']
        self.group_name = f'conversation_{publication_id}'
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, 'group_name'):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def receive(self, text_data=None, bytes_data=None):
        # Canal descendant uniquement : l'envoi de message passe toujours
        # par l'API REST classique (POST /comments/), qui déclenche ensuite
        # la diffusion via signals.py. On n'accepte jamais un message
        # entrant à écrire en base directement depuis le WebSocket — ça
        # contournerait toutes les validations/permissions du serializer
        # REST (modération, appartenance, etc.).
        pass

    async def new_message(self, event):
        await self.send(text_data=json.dumps(event['payload']))
