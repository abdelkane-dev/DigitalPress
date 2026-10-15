"""Tests du flux d'activation de compte par email (OTP 15 min).

Note Dr. Sissoko (2026-08-16) : chaque création de compte exige une
validation par email pour activer le compte (tous types de profils), le
numéro de téléphone est requis à l'inscription, et la connexion reste
bloquée tant que l'email n'a pas été validé.
"""
import re

from django.core import mail
from django.core.cache import cache
from django.test import TestCase
from rest_framework.test import APIClient

from .models import User


def _extract_code():
    """Récupère le code OTP depuis la boîte mail de test (locmem)."""
    for message in mail.outbox:
        if 'Activez votre compte' in message.subject:
            match = re.search(r"code d'activation est : (\d{6})", message.body)
            if match:
                return match.group(1)
    return None


class EmailVerificationTests(TestCase):
    def setUp(self):
        # Le cache LocMem des throttles est PARTAGÉ entre les tests du même
        # process : sans vidage, les compteurs s'accumulent et finissent par
        # déclencher un 429 (disponible dans N secondes) sur le dernier test.
        cache.clear()
        self.client = APIClient()

    def _register(self, **overrides):
        payload = {
            'username': 'testreader1',
            'email': 'test1@example.com',
            'password': 'StrongPass123!',
            'password2': 'StrongPass123!',
            'role': 'reader',
            'phone': '+22370000000',
        }
        payload.update(overrides)
        return self.client.post('/api/accounts/register/', payload, format='json')

    def test_register_requires_phone(self):
        response = self._register(phone='')
        self.assertEqual(response.status_code, 400)
        self.assertIn('phone', response.json()['errors'])

    def test_register_emits_verification_required(self):
        response = self._register()
        self.assertEqual(response.status_code, 201)
        self.assertTrue(response.json().get('email_verification_required'))
        user = User.objects.get(email='test1@example.com')
        self.assertFalse(user.is_verified)
        # Un email d'activation a été envoyé.
        self.assertTrue(
            any('Activez votre compte' in m.subject for m in mail.outbox)
        )

    def test_login_blocked_before_verification(self):
        self._register()
        response = self.client.post(
            '/api/accounts/login/',
            {'username': 'testreader1', 'password': 'StrongPass123!'},
            format='json',
        )
        self.assertEqual(response.status_code, 400)
        # DRF normalise chaque champ d'erreur en liste (['email_not_verified']).
        self.assertEqual(response.json()['errors']['code'], ['email_not_verified'])

    def test_verify_email_with_wrong_code_fails(self):
        self._register()
        response = self.client.post(
            '/api/accounts/verify-email/',
            {'email': 'test1@example.com', 'code': '000000'},
            format='json',
        )
        self.assertEqual(response.status_code, 400, response.content[:300])

    def test_full_flow_register_verify_login(self):
        self._register()
        code = _extract_code()
        self.assertIsNotNone(code, 'Un code OTP doit avoir été envoyé par email')

        response = self.client.post(
            '/api/accounts/verify-email/',
            {'email': 'test1@example.com', 'code': code},
            format='json',
        )
        self.assertEqual(response.status_code, 200)
        user = User.objects.get(email='test1@example.com')
        self.assertTrue(user.is_verified)

        response = self.client.post(
            '/api/accounts/login/',
            {'username': 'testreader1', 'password': 'StrongPass123!'},
            format='json',
        )
        self.assertEqual(response.status_code, 200)
        self.assertIn('access', response.json())

    def test_resend_verification_code(self):
        self._register()
        mail.outbox.clear()
        response = self.client.post(
            '/api/accounts/resend-email-verification/',
            {'email': 'test1@example.com'},
            format='json',
        )
        self.assertEqual(response.status_code, 200)
        self.assertTrue(
            any('Activez votre compte' in m.subject for m in mail.outbox)
        )

    def test_publisher_registration_also_requires_verification(self):
        response = self._register(
            username='testpublisher1',
            email='pub1@example.com',
            role='publisher',
            company_name='Presse Test',
        )
        self.assertEqual(response.status_code, 201)
        user = User.objects.get(email='pub1@example.com')
        self.assertEqual(user.role, 'publisher')
        self.assertFalse(user.is_verified)

    # ─── COMPTES CRÉÉS VIA GOOGLE/FACEBOOK : ACTIVATION EMAIL OBLIGATOIRE ──
    # (demande explicite) : un compte créé via un fournisseur social démarre
    # NON VÉRIFIÉ comme un compte classique — l'utilisateur doit valider
    # l'OTP reçu par email avant de pouvoir se connecter.

    @staticmethod
    def _fake_google_idinfo(email='social.google@example.com'):
        return {
            'email': email,
            'name': 'Social Google',
            'picture': 'https://example.com/avatar.png',
        }

    def _google_login(self, email='social.google@example.com'):
        from unittest import mock
        from django.test import override_settings
        with override_settings(GOOGLE_OAUTH_CLIENT_ID='test-client-id'):
            with mock.patch(
                'google.oauth2.id_token.verify_oauth2_token',
                return_value=self._fake_google_idinfo(email),
            ):
                return self.client.post(
                    '/api/accounts/auth/google/',
                    {'id_token': 'fake-token'},
                    format='json',
                )

    def test_google_created_account_requires_email_activation(self):
        response = self._google_login()
        self.assertEqual(response.status_code, 200)
        data = response.json()
        # Pas de jeton tant que l'email n'est pas activé.
        self.assertNotIn('access', data)
        self.assertTrue(data.get('email_verification_required'))

        user = User.objects.get(email='social.google@example.com')
        self.assertFalse(user.is_verified)
        # Un email d'activation a été envoyé.
        self.assertTrue(
            any('Activez votre compte' in m.subject for m in mail.outbox)
        )

        # Après validation du code OTP, la connexion Google délivre les jetons.
        code = _extract_code()
        self.assertIsNotNone(code)
        verify = self.client.post(
            '/api/accounts/verify-email/',
            {'email': 'social.google@example.com', 'code': code},
            format='json',
        )
        self.assertEqual(verify.status_code, 200)

        response = self._google_login()
        self.assertEqual(response.status_code, 200)
        self.assertIn('access', response.json())

    def test_google_existing_unverified_account_never_gets_token(self):
        # Un compte existant jamais activé (ex: créé avant l'activation
        # obligatoire) reste bloqué tant que son email n'est pas validé.
        user = User.objects.create_user(
            username='old_google_user',
            email='old.google@example.com',
            is_verified=False,
            role='reader',
        )
        response = self._google_login(email='old.google@example.com')
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertNotIn('access', data)
        self.assertTrue(data.get('email_verification_required'))
        user.refresh_from_db()
        self.assertFalse(user.is_verified)
