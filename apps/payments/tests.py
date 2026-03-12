from django.test import TestCase, Client
from django.urls import reverse
from django.contrib.auth import get_user_model
from django.conf import settings
import json

from .models import Payment
from apps.subscriptions.models import Subscription


class PaymentWebhookTests(TestCase):
    def setUp(self):
        self.client = Client()
        User = get_user_model()
        self.user = User.objects.create_user(username='tester', password='pass')

    def test_webhook_success_updates_payment_and_creates_subscription(self):
        payment = Payment.objects.create(
            user=self.user,
            amount=1000.00,
            status='pending',
            payment_method='mobile_money'
        )

        payload = {
            'clientReference': str(payment.id),
            'status': 'SUCCESSFUL',
            'transactionId': 'tx-001',
            'subscription_type': 'monthly'
        }

        url = reverse('payment-webhook')
        resp = self.client.post(url, data=json.dumps(payload), content_type='application/json')
        self.assertEqual(resp.status_code, 200)

        payment.refresh_from_db()
        self.assertEqual(payment.status, 'success')

        sub_exists = Subscription.objects.filter(user=self.user, subscription_type='monthly').exists()
        self.assertTrue(sub_exists)

    def test_webhook_missing_reference_returns_400(self):
        payload = {'status': 'SUCCESSFUL', 'transactionId': 'tx-002'}
        url = reverse('payment-webhook')
        resp = self.client.post(url, data=json.dumps(payload), content_type='application/json')
        self.assertEqual(resp.status_code, 400)
        data = resp.json()
        self.assertIn('error', data)
from django.test import TestCase

# Create your tests here.
