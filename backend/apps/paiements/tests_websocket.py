"""Tests de la diffusion temps réel (WebSocket) des transactions.

Garantit que chaque Transaction créée/mise à jour diffuse bien l'événement
'stats_changed' sur le canal WebSocket personnel du PAYEUR et du
BÉNÉFICIAIRE (plus 'admin_stats_changed' aux admins connectés) — c'est ce
qui fait rafraîchir les stats du profil en temps réel côté app Flutter
(ProfileScreen écoute realtimeEventProvider), sans attendre la réouverture
de la page.
"""
from unittest import mock

from django.contrib.auth import get_user_model
from django.test import TestCase

from apps.paiements.models import DemandeRetrait, Transaction


class WebSocketStatsBroadcastTests(TestCase):
    def setUp(self):
        self.User = get_user_model()
        self.payer = self.User.objects.create_user(
            username='ws-payer', password='secret123', role='reader'
        )
        self.beneficiaire = self.User.objects.create_user(
            username='ws-benef', password='secret123', role='publisher'
        )

    def _patch_realtime(self):
        """Remplace les vraies fonctions de diffusion (elles touchent le
        channel layer Channels/Redis, indisponible en test) par des mock."""
        return (
            mock.patch('apps.notifications.realtime.push_to_user'),
            mock.patch('apps.notifications.realtime.push_to_admins'),
        )

    def test_success_transaction_broadcasts_stats_changed_to_payer_and_beneficiary(self):
        """Une transaction au statut 'success' (ex: webhook CinetPay qui
        valide un paiement) diffuse 'stats_changed' au payeur ET au
        bénéficiaire, plus 'admin_stats_changed' aux admins."""
        push_user_patcher, push_admins_patcher = self._patch_realtime()
        with push_user_patcher as push_user, push_admins_patcher as push_admins:
            Transaction.objects.create(
                payer=self.payer,
                beneficiaire=self.beneficiaire,
                type_transaction='purchase',
                montant_brut='1000.00',
                montant_net='800.00',
                status='success',
            )

        push_user.assert_any_call(
            self.payer.id, 'stats_changed', {'reason': 'transaction'}
        )
        push_user.assert_any_call(
            self.beneficiaire.id, 'stats_changed', {'reason': 'transaction'}
        )
        push_admins.assert_any_call(
            'admin_stats_changed', {'reason': 'transaction'}
        )

    def test_status_update_to_success_also_broadcasts(self):
        """Le passage pending → success (mise à jour d'une transaction
        existante, comme le fait le polling / le webhook) diffuse lui aussi
        l'événement — c'est le moment exact où l'app doit rafraîchir."""
        tx = Transaction.objects.create(
            payer=self.payer,
            beneficiaire=self.beneficiaire,
            type_transaction='purchase',
            montant_brut='1000.00',
            montant_net='800.00',
            status='pending',
        )
        push_user_patcher, push_admins_patcher = self._patch_realtime()
        with push_user_patcher as push_user, push_admins_patcher as push_admins:
            tx.status = 'success'
            tx.save(update_fields=['status'])

        push_user.assert_any_call(
            self.payer.id, 'stats_changed', {'reason': 'transaction'}
        )
        push_user.assert_any_call(
            self.beneficiaire.id, 'stats_changed', {'reason': 'transaction'}
        )

    def test_withdrawal_request_broadcasts_to_editor_and_admins(self):
        """Une demande de retrait alerte l'éditeur en direct (ses stats /
        solde changent) et les admins (file à traiter)."""
        editeur = self.beneficiaire
        push_user_patcher, push_admins_patcher = self._patch_realtime()
        with push_user_patcher as push_user, push_admins_patcher as push_admins:
            DemandeRetrait.objects.create(
                editeur=editeur,
                montant='5000.00',
                mode_paiement='mobile_money',
                numero_compte='+22370000000',
            )

        push_user.assert_any_call(
            editeur.id, 'stats_changed', {'reason': 'withdrawal'}
        )
        push_admins.assert_any_call(
            'admin_stats_changed', {'reason': 'new_withdrawal'}
        )
