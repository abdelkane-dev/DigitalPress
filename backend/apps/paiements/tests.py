from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIRequestFactory, force_authenticate

from apps.comptabilite.utils import get_dashboard_stats
from apps.paiements.views import DemanderRetraitView


class AdminAccountingTests(TestCase):
    def test_legacy_entreprise_retrait_route_is_available(self):
        User = get_user_model()
        user = User.objects.create_user(
            username='legacy-withdraw',
            password='secret123',
            role='admin',
            solde=5000,
        )

        factory = APIRequestFactory()
        request = factory.post(
            '/api/entreprise/retrait/demander/',
            data={
                'montant': 1000,
                'mode_paiement': 'mobile_money',
                'numero_compte': '+22501020304',
            },
            format='json',
        )
        force_authenticate(request, user=user)

        response = DemanderRetraitView.as_view()(request)

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['editeur'], user.id)

    def test_dashboard_stats_exposes_indicator_fields(self):
        stats = get_dashboard_stats()

        self.assertIn('chiffre_affaires_brut', stats)
        self.assertIn('commissions_collectees', stats)
        self.assertIn('retraits_valides', stats)
        self.assertIn('nb_transactions_success', stats)

    def test_admin_can_request_withdrawal_from_own_account(self):
        User = get_user_model()
        user = User.objects.create_user(
            username='admin-withdraw',
            password='secret123',
            role='admin',
            solde=5000,
        )

        factory = APIRequestFactory()
        request = factory.post(
            '/api/paiements/retrait/demander/',
            data={
                'montant': 1000,
                'mode_paiement': 'mobile_money',
                'numero_compte': '+22501020304',
            },
            format='json',
        )
        force_authenticate(request, user=user)

        response = DemanderRetraitView.as_view()(request)

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['editeur'], user.id)
