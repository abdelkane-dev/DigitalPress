from django.utils import timezone
from django.conf import settings
import logging
import json
import requests

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import permissions, status
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from rest_framework.permissions import IsAuthenticated
from rest_framework import serializers

from .serializers import InvoiceSerializer

from .models import Payment
from apps.subscriptions.models import Subscription
from apps.subscriptions.utils import calculate_end_date

logger = logging.getLogger(__name__)


class ProcessPaymentView(APIView):
    """Endpoint utilisé par le client Flutter pour initialiser un paiement.

    - Crée un enregistrement Payment en `pending`.
    - Retourne un `payment_id` et un `client_secret` (placeholder).
    - L'intégration réelle avec Stripe/Momo doit créer l'intent côté serveur
      en ajoutant `metadata={'payment_id': payment.id, 'subscription_type': ...}`
      pour retrouver le paiement dans le webhook.
    """

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        amount = request.data.get('amount')
        method = request.data.get('payment_method', 'card')
        sub_type = request.data.get('subscription_type')

        if amount is None:
            return Response({'error': 'amount is required'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            amount_value = float(amount)
        except Exception:
            return Response({'error': 'amount must be numeric'}, status=status.HTTP_400_BAD_REQUEST)

        payment = Payment.objects.create(
            user=request.user,
            amount=amount_value,
            status='pending',
            payment_method=method,
        )

        # Si Orange Money est configuré, appeler l'API pour initier le paiement
        orange_base = getattr(settings, 'ORANGE_BASE_URL', None)
        orange_key = getattr(settings, 'ORANGE_API_KEY', None)
        orange_secret = getattr(settings, 'ORANGE_API_SECRET', None)

        if orange_base and orange_key:
            try:
                # Exemple générique: POST {amount, currency, clientReference} -> provider response
                url = f"{orange_base.rstrip('/')}/payments/v1/requests"
                headers = {
                    'Content-Type': 'application/json',
                    'Authorization': f'Bearer {orange_key}'
                }
                body = {
                    'amount': str(amount_value),
                    'currency': getattr(settings, 'ORANGE_CURRENCY', 'XOF'),
                    'clientReference': str(payment.id),
                    'description': f'Subscription {sub_type} for user {request.user.id}',
                }
                # Certains providers exigent un token OAuth; support minimal ici
                resp = requests.post(url, headers=headers, data=json.dumps(body), timeout=10)
                resp.raise_for_status()
                data = resp.json()
                # Le provider devrait renvoyer une référence externe que le client peut utiliser
                provider_ref = data.get('transactionId') or data.get('requestId') or data.get('provider_ref')
                return Response({
                    'payment_id': payment.id,
                    'provider_ref': provider_ref,
                    'provider_response': data,
                }, status=status.HTTP_201_CREATED)
            except requests.RequestException:
                logger.exception('Orange Money request failed')

        # Fallback: retourner placeholder si aucun provider configuré
        return Response({
            'payment_id': payment.id,
            'message': 'Payment created in pending state. Configure ORANGE_BASE_URL and ORANGE_API_KEY to initiate provider flow.'
        }, status=status.HTTP_201_CREATED)


class PaymentStatusView(APIView):
    """Return payment status. Authenticated users only; owner or staff can access."""
    permission_classes = [IsAuthenticated]

    def get(self, request, payment_id):
        try:
            payment = Payment.objects.get(id=payment_id)
        except Payment.DoesNotExist:
            return Response({'error': 'payment not found'}, status=status.HTTP_404_NOT_FOUND)

        if not (request.user.is_staff or payment.user_id == request.user.id):
            return Response({'error': 'forbidden'}, status=status.HTTP_403_FORBIDDEN)

        data = {
            'payment_id': payment.id,
            'status': payment.status,
            'amount': str(payment.amount),
            'payment_method': payment.payment_method,
            'created_at': payment.created_at,
        }
        # include provider_ref if stored on DB or in related invoice/provider_response
        return Response(data, status=status.HTTP_200_OK)


class PaymentInvoiceView(APIView):
    """Return invoice details or PDF url for a payment. Owner or staff only."""
    permission_classes = [IsAuthenticated]

    def get(self, request, payment_id):
        try:
            payment = Payment.objects.get(id=payment_id)
        except Payment.DoesNotExist:
            return Response({'error': 'payment not found'}, status=status.HTTP_404_NOT_FOUND)

        if not (request.user.is_staff or payment.user_id == request.user.id):
            return Response({'error': 'forbidden'}, status=status.HTTP_403_FORBIDDEN)

        # Invoice is a OneToOne relation on Payment (apps/payments/models.py)
        try:
            invoice = payment.invoice
        except Exception:
            return Response({'error': 'invoice not found'}, status=status.HTTP_404_NOT_FOUND)

        serializer = InvoiceSerializer(invoice, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)


@method_decorator(csrf_exempt, name='dispatch')
class PaymentWebhookView(APIView):
    """Endpoint public pour recevoir les webhooks des prestataires de paiement.

    Attente d'un payload contenant une référence à notre `payment_id` dans
    `metadata.payment_id` ou `payment_id` au niveau racine. Met à jour le
    statut du `Payment` et crée l'abonnement si le paiement est confirmé.
    """

    permission_classes = [permissions.AllowAny]

    def post(self, request):
        try:
            payload = request.data
        except Exception as e:
            logger.exception('Invalid webhook payload')
            return Response(status=status.HTTP_400_BAD_REQUEST)

        # Vérification simple si ORANGE_WEBHOOK_SECRET est configuré
        sig_header = request.META.get('HTTP_X_SIGNATURE') or request.headers.get('X-Signature')
        webhook_secret = getattr(settings, 'ORANGE_WEBHOOK_SECRET', None)
        if webhook_secret and sig_header:
            if sig_header != webhook_secret:
                logger.warning('Invalid webhook signature')
                return Response({'error': 'invalid signature'}, status=status.HTTP_400_BAD_REQUEST)

        # Récupération du payment_id selon plusieurs formats possibles
        payment_ref = None
        status_str = None

        # Orange Money webhook format varies; rechercher les champs communs
        if isinstance(payload, dict):
            # ex: {"clientReference": "123", "status": "SUCCESSFUL", "transactionId": "abc"}
            payment_ref = payload.get('clientReference') or payload.get('client_reference') or payload.get('payment_id')
            status_str = payload.get('status') or payload.get('payment_status') or payload.get('event')
            # Certains nested: payload['data']['object']
            if not payment_ref and 'data' in payload and isinstance(payload['data'], dict):
                obj = payload['data'].get('object') or payload['data']
                if isinstance(obj, dict):
                    payment_ref = obj.get('clientReference') or obj.get('client_reference') or obj.get('payment_id')
                    status_str = status_str or obj.get('status')

        if not payment_ref:
            logger.warning('webhook missing payment reference: %s', payload)
            return Response({'error': 'missing payment reference'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            payment = Payment.objects.get(id=int(payment_ref))
        except Exception:
            logger.exception('Payment not found for webhook reference %s', payment_ref)
            return Response({'error': 'payment not found'}, status=status.HTTP_404_NOT_FOUND)

        # Normalisation des statuts
        success_values = ('succeeded', 'success', 'paid', 'completed')
        failed_values = ('failed', 'failed_payment', 'canceled', 'cancelled')

        if status_str:
            status_lower = str(status_str).lower()
            if any(s in status_lower for s in success_values):
                payment.status = 'success'
                payment.save()
                # Créer l'abonnement si la metadata contient subscription_type
                try:
                    sub_type = None
                    if isinstance(payload, dict):
                        md = None
                        if 'data' in payload and isinstance(payload['data'], dict):
                            md = payload['data']['object'].get('metadata', {})
                        else:
                            md = payload.get('metadata', {})
                        sub_type = (md or {}).get('subscription_type')
                    if sub_type:
                        Subscription.objects.create(
                            user=payment.user,
                            subscription_type=sub_type,
                            start_date=timezone.now().date(),
                            end_date=calculate_end_date(sub_type),
                            status='active',
                            price=payment.amount
                        )
                except Exception:
                    logger.exception('Failed to create subscription after payment success')
                return Response({'status': 'ok'}, status=status.HTTP_200_OK)
            elif any(s in status_lower for s in failed_values):
                payment.status = 'failed'
                payment.save()
                return Response({'status': 'ok'}, status=status.HTTP_200_OK)

        # Fallbacks
        if isinstance(payload, dict) and payload.get('paid') is True:
            payment.status = 'success'
            payment.save()
            return Response({'status': 'ok'}, status=status.HTTP_200_OK)

        return Response({'status': 'ignored'}, status=status.HTTP_200_OK)