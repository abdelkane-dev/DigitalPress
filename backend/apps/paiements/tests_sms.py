"""Tests du canal SMS des retraits (fournisseur Twilio).

Couvre :
- la détection de configuration (clés .env présentes ou non) ;
- la normalisation des numéros vers E.164 ;
- le repli sûr quand aucun fournisseur n'est configuré (le code est
  journalisé, jamais perdu, la demande ne plante pas) ;
- le format exact de l'appel à l'API REST Twilio quand les clés existent ;
- l'endpoint POST /paiements/retrait/otp/ avec canal 'sms' (le code part
  bien par le service SMS sans bloquer le flux).
"""
from unittest import mock

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from rest_framework.test import APIRequestFactory, force_authenticate

from apps.paiements.sms import (
    normalize_phone,
    send_withdrawal_otp,
    sms_provider_configured,
)


class SmsProviderConfigurationTests(TestCase):
    @override_settings(TWILIO_ACCOUNT_SID='', TWILIO_AUTH_TOKEN='', TWILIO_FROM_NUMBER='')
    def test_not_configured_when_keys_empty(self):
        self.assertFalse(sms_provider_configured())

    @override_settings(
        TWILIO_ACCOUNT_SID='ACxxxxxxxx',
        TWILIO_AUTH_TOKEN='token',
        TWILIO_FROM_NUMBER='+15017122661',
    )
    def test_configured_when_all_keys_present(self):
        self.assertTrue(sms_provider_configured())

    @override_settings(
        TWILIO_ACCOUNT_SID='ACxxxxxxxx',
        TWILIO_AUTH_TOKEN='',
        TWILIO_FROM_NUMBER='+15017122661',
    )
    def test_not_configured_when_one_key_missing(self):
        self.assertFalse(sms_provider_configured())


class NormalizePhoneTests(TestCase):
    @override_settings(TWILIO_DEFAULT_COUNTRY_CODE='223')
    def test_local_number_gets_default_country_code(self):
        self.assertEqual(normalize_phone('70 00 00 00'), '+22370000000')

    @override_settings(TWILIO_DEFAULT_COUNTRY_CODE='223')
    def test_local_number_with_spaces_and_leading_zero(self):
        self.assertEqual(normalize_phone('70 12 34 56'), '+22370123456')

    def test_international_number_kept_as_is(self):
        self.assertEqual(normalize_phone('+221 77 123 45 67'), '+221771234567')

    @override_settings(TWILIO_DEFAULT_COUNTRY_CODE='221')
    def test_custom_default_country_code(self):
        self.assertEqual(normalize_phone('77 123 45 67'), '+221771234567')


class SendWithdrawalOtpTests(TestCase):
    def setUp(self):
        self.User = get_user_model()
        self.user = self.User.objects.create_user(
            username='sms-editor',
            password='secret123',
            role='publisher',
            phone='70 00 00 00',
        )

    @override_settings(TWILIO_ACCOUNT_SID='', TWILIO_AUTH_TOKEN='', TWILIO_FROM_NUMBER='')
    def test_no_provider_returns_false_without_network(self):
        # Aucun fournisseur configuré : pas d'appel réseau, pas d'exception,
        # retour False (le code est journalisé, l'email fait foi).
        with mock.patch('requests.post') as mocked_post:
            sent = send_withdrawal_otp(self.user, '123456')
        self.assertFalse(sent)
        mocked_post.assert_not_called()

    @override_settings(
        TWILIO_ACCOUNT_SID='ACxxxxxxxx',
        TWILIO_AUTH_TOKEN='token',
        TWILIO_FROM_NUMBER='+15017122661',
    )
    def test_calls_twilio_with_e164_phone_and_code(self):
        with mock.patch('requests.post') as mocked_post:
            mocked_post.return_value = mock.Mock(
                raise_for_status=lambda: None,
                json=lambda: {'sid': 'SM123'},
            )
            sent = send_withdrawal_otp(self.user, '654321')

        self.assertTrue(sent)
        mocked_post.assert_called_once()
        call = mocked_post.call_args
        self.assertEqual(
            call.args[0],
            'https://api.twilio.com/2010-04-01/Accounts/ACxxxxxxxx/Messages.json',
        )
        self.assertEqual(call.kwargs['auth'], ('ACxxxxxxxx', 'token'))
        self.assertEqual(
            call.kwargs['data'],
            {
                'From': '+15017122661',
                'To': '+22370000000',  # numéro local normalisé en E.164
                'Body': mock.ANY,
            },
        )
        self.assertIn('654321', call.kwargs['data']['Body'])

    @override_settings(
        TWILIO_ACCOUNT_SID='ACxxxxxxxx',
        TWILIO_AUTH_TOKEN='token',
        TWILIO_FROM_NUMBER='+15017122661',
    )
    def test_user_without_phone_returns_false(self):
        self.user.phone = ''
        self.user.save()
        with mock.patch('requests.post') as mocked_post:
            sent = send_withdrawal_otp(self.user, '111111')
        self.assertFalse(sent)
        mocked_post.assert_not_called()

    @override_settings(
        TWILIO_ACCOUNT_SID='ACxxxxxxxx',
        TWILIO_AUTH_TOKEN='token',
        TWILIO_FROM_NUMBER='+15017122661',
    )
    def test_twilio_refusal_raises(self):
        # Si Twilio refuse (clés invalides, solde insuffisant...), une
        # exception remonte : WithdrawalOtpView._deliver_sms la capture et
        # journalise sans bloquer la demande (l'email est déjà parti).
        from apps.paiements.views import WithdrawalOtpView

        with mock.patch('requests.post') as mocked_post:
            mocked_post.side_effect = Exception('HTTP 401: Invalid credentials')
            with self.assertRaises(Exception):
                send_withdrawal_otp(self.user, '222222')

        # Et au niveau de la vue, l'échec n'empêche pas la réponse 200.
        factory = APIRequestFactory()
        request = factory.post('/api/paiements/retrait/otp/', data={'channel': 'sms'}, format='json')
        force_authenticate(request, user=self.user)
        response = WithdrawalOtpView.as_view()(request)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['channel'], 'sms')


class WithdrawalOtpSmsChannelTests(TestCase):
    def setUp(self):
        self.User = get_user_model()
        self.user = self.User.objects.create_user(
            username='otp-sms-user',
            password='secret123',
            role='publisher',
            phone='+22370000000',
            email='otp-sms@example.com',
        )

    @override_settings(TWILIO_ACCOUNT_SID='', TWILIO_AUTH_TOKEN='', TWILIO_FROM_NUMBER='')
    def test_sms_channel_ok_without_provider(self):
        from apps.paiements.views import WithdrawalOtpView

        factory = APIRequestFactory()
        request = factory.post('/api/paiements/retrait/otp/', data={'channel': 'sms'}, format='json')
        force_authenticate(request, user=self.user)
        response = WithdrawalOtpView.as_view()(request)

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['channel'], 'sms')
        self.assertIn('message', response.data)
        # Le destinataire est masqué, jamais révélé en clair.
        self.assertTrue(response.data['destination'].endswith('@example.com'))
        self.assertNotIn('70000000', response.data['destination'])

    @override_settings(
        TWILIO_ACCOUNT_SID='ACxxxxxxxx',
        TWILIO_AUTH_TOKEN='token',
        TWILIO_FROM_NUMBER='+15017122661',
    )
    def test_sms_channel_calls_real_provider(self):
        from apps.paiements.views import WithdrawalOtpView

        with mock.patch('requests.post') as mocked_post:
            mocked_post.return_value = mock.Mock(
                raise_for_status=lambda: None,
                json=lambda: {'sid': 'SM456'},
            )
            factory = APIRequestFactory()
            request = factory.post(
                '/api/paiements/retrait/otp/', data={'channel': 'sms'}, format='json'
            )
            force_authenticate(request, user=self.user)
            response = WithdrawalOtpView.as_view()(request)

        self.assertEqual(response.status_code, 200)
        mocked_post.assert_called_once()
        # Le SMS part bien vers le numéro E.164 de l'utilisateur.
        self.assertEqual(mocked_post.call_args.kwargs['data']['To'], '+22370000000')

    def test_invalid_channel_rejected(self):
        from apps.paiements.views import WithdrawalOtpView

        factory = APIRequestFactory()
        request = factory.post('/api/paiements/retrait/otp/', data={'channel': 'carrier_pigeon'}, format='json')
        force_authenticate(request, user=self.user)
        response = WithdrawalOtpView.as_view()(request)
        self.assertEqual(response.status_code, 400)
