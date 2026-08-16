from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIRequestFactory, force_authenticate

from apps.comptabilite.utils import get_dashboard_stats
from apps.paiements.views import DemanderRetraitView


def _otp_code_for(user):
    """Émet un code OTP de retrait pour `user` et retourne le code en clair."""
    from apps.paiements.models import WithdrawalVerificationCode
    return WithdrawalVerificationCode.issue_for(user, channel='email')


def _withdraw_request(user, **overrides):
    data = {
        'montant': 1000,
        'mode_paiement': 'mobile_money',
        'numero_compte': '+22501020304',
    }
    data.update(overrides)
    factory = APIRequestFactory()
    request = factory.post('/api/paiements/retrait/demander/', data=data, format='json')
    force_authenticate(request, user=user)
    return DemanderRetraitView.as_view()(request)


class AdminAccountingTests(TestCase):
    def test_legacy_entreprise_retrait_route_is_available(self):
        User = get_user_model()
        user = User.objects.create_user(
            username='legacy-withdraw',
            password='secret123',
            role='admin',
            solde=5000,
        )

        # Un code OTP est requis avant de valider un retrait (protection
        # contre les retraits frauduleux) : sans code, la demande est refusée.
        response = _withdraw_request(user)
        self.assertEqual(response.status_code, 400)
        self.assertIn('otp_code', response.data.get('errors', {}))

        # Avec le code OTP valide, la demande passe.
        code = _otp_code_for(user)
        response = _withdraw_request(user, otp_code=code)
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

        # Un code OTP invalide est refusé même si le solde est suffisant.
        response = _withdraw_request(user, otp_code='000000')
        self.assertEqual(response.status_code, 400)

        code = _otp_code_for(user)
        response = _withdraw_request(user, otp_code=code)
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['editeur'], user.id)


class PaymentSimulationAndEngineTests(TestCase):
    def test_sandbox_simulation_initiation_and_verification(self):
        from apps.paiements.views import InitierPaiementView, VerifierPaiementView
        from apps.paiements.models import Transaction

        User = get_user_model()
        user = User.objects.create_user(
            username='test-sandbox-user',
            password='secret123',
            solde=0,
        )

        factory = APIRequestFactory()
        # 1. Initiating recharge in sandbox mode
        init_req = factory.post(
            '/api/paiements/initier/',
            data={
                'type_transaction': 'recharge',
                'mode_paiement': 'movapay',
                'montant': 5000,
                'phone': '+22370000000',
            },
            format='json',
        )
        force_authenticate(init_req, user=user)

        init_resp = InitierPaiementView.as_view()(init_req)
        self.assertEqual(init_resp.status_code, 201)
        self.assertIn('payment_url', init_resp.data)
        # CinetPay : URL de checkout simulée (sandbox.cinetpay.com).
        self.assertTrue(init_resp.data['payment_url'].startswith('https://sandbox.cinetpay.com/checkout/'))

        tx_ref = init_resp.data['transaction']['reference']
        tx = Transaction.objects.get(reference=tx_ref)
        self.assertEqual(tx.status, 'pending')

        # 2. Verifying transaction in sandbox mode
        verify_req = factory.post(
            '/api/paiements/verifier/',
            data={'reference': tx_ref},
            format='json',
        )
        force_authenticate(verify_req, user=user)

        verify_resp = VerifierPaiementView.as_view()(verify_req)
        self.assertEqual(verify_resp.status_code, 200)

        tx.refresh_from_db()
        self.assertEqual(tx.status, 'success')
        user.refresh_from_db()
        self.assertEqual(user.solde, 5000)

    def test_explicit_simulation_mode_supported(self):
        from apps.paiements.views import InitierPaiementView
        User = get_user_model()
        user = User.objects.create_user(
            username='test-explicit-sim-user',
            password='secret123',
            solde=0,
        )
        factory = APIRequestFactory()
        req = factory.post(
            '/api/paiements/initier/',
            data={
                'type_transaction': 'recharge',
                'mode_paiement': 'simulation',
                'montant': 2000,
            },
            format='json',
        )
        force_authenticate(req, user=user)
        resp = InitierPaiementView.as_view()(req)
        self.assertEqual(resp.status_code, 201)
        self.assertIn('sandbox.cinetpay.com', resp.data['payment_url'])

    def test_dynamic_api_key_sandbox_detection(self):
        from django.conf import settings
        from apps.paiements.cinetpay import is_sandbox_mode

        # Default without keys
        original_key = getattr(settings, 'CINETPAY_API_KEY', '')
        original_site = getattr(settings, 'CINETPAY_SITE_ID', '')
        try:
            settings.CINETPAY_API_KEY = ''
            settings.CINETPAY_SITE_ID = ''
            self.assertTrue(is_sandbox_mode())

            settings.CINETPAY_API_KEY = 'YOUR_CINETPAY_KEY'
            self.assertTrue(is_sandbox_mode())

            settings.CINETPAY_API_KEY = 'live_key_real_123456'
            settings.CINETPAY_SITE_ID = '123456'
            self.assertFalse(is_sandbox_mode())
        finally:
            settings.CINETPAY_API_KEY = original_key
            settings.CINETPAY_SITE_ID = original_site

