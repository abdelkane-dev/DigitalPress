"""
Service d'intégration Movapay — passerelle de paiement mobile money.
Documentation: https://api.movapay.com/v1/docs
"""
import hashlib
import hmac
import uuid
import logging
import requests
from django.conf import settings

logger = logging.getLogger(__name__)

MOVAPAY_BASE_URL = getattr(settings, 'MOVAPAY_BASE_URL', 'https://api.movapay.com/v1')
MOVAPAY_API_KEY = getattr(settings, 'MOVAPAY_API_KEY', '')
MOVAPAY_SECRET = getattr(settings, 'MOVAPAY_SECRET', '')
MOVAPAY_TIMEOUT = 30  # secondes

_PLACEHOLDER_VALUES = ('', 'YOUR_MOVAPAY_KEY', 'YOUR_MOVAPAY_API_KEY', 'YOUR_MOVAPAY_SECRET')


def is_sandbox_mode() -> bool:
    """Vrai si aucune clé Movapay réelle n'est configurée (mode démo/local)."""
    key = getattr(settings, 'MOVAPAY_API_KEY', '')
    return not key or key in _PLACEHOLDER_VALUES


def verify_webhook_signature(raw_body: bytes, signature_header: str) -> bool:
    """Vérifie la signature HMAC-SHA256 d'un webhook Movapay.

    Movapay signe chaque notification avec la clé secrète du compte
    marchand ; le webhook doit reproduire ce calcul et comparer les deux
    signatures de façon résistante aux attaques temporelles
    (`hmac.compare_digest`). Sans cette vérification, n'importe qui pouvait
    auparavant appeler `/api/paiements/webhook/` (accessible sans
    authentification, comme l'exige un vrai webhook) avec un statut
    "success" fabriqué et créditer frauduleusement n'importe quel compte.

    En mode sandbox (aucune clé Movapay réelle configurée), la vérification
    est ignorée pour permettre les tests locaux avec le service simulé.
    """
    if is_sandbox_mode():
        logger.warning(
            "Webhook Movapay reçu en mode sandbox : signature non vérifiée "
            "(aucune clé Movapay réelle configurée)."
        )
        return True

    secret = getattr(settings, 'MOVAPAY_SECRET', '')
    if not signature_header or not secret:
        return False

    expected = hmac.new(
        secret.encode('utf-8'), raw_body, hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected, signature_header)


class MovapayService:
    """Client HTTP pour l'API Movapay."""

    @property
    def base_url(self) -> str:
        return getattr(settings, 'MOVAPAY_BASE_URL', 'https://api.movapay.com/v1')

    @property
    def api_key(self) -> str:
        return getattr(settings, 'MOVAPAY_API_KEY', '')

    @property
    def secret(self) -> str:
        return getattr(settings, 'MOVAPAY_SECRET', '')

    def _get_session(self) -> requests.Session:
        session = requests.Session()
        api_key = self.api_key
        session.headers.update({
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json',
            'X-API-Key': api_key,
        })
        return session

    def _url(self, endpoint):
        return f"{self.base_url.rstrip('/')}/{endpoint.lstrip('/')}"

    def initier_paiement(self, montant: float, phone: str, reference: str,
                         description: str = '', currency: str = 'XOF') -> dict:
        """
        Initie une transaction de paiement mobile money.

        Returns:
            dict: {success, payment_url, movapay_ref, message}
        """
        payload = {
            'amount': str(montant),
            'currency': currency,
            'phone': phone,
            'external_ref': reference,
            'description': description or f'Digital Press — {reference}',
            'callback_url': f"{getattr(settings, 'BACKEND_URL', 'http://localhost:8000')}/api/paiements/webhook/",
            'return_url': getattr(settings, 'FRONTEND_SUCCESS_URL', 'http://localhost:3000/payment/success'),
        }
        try:
            if is_sandbox_mode():
                logger.warning("Movapay API key not configured — using sandbox mock.")
                return self._mock_initier(reference, montant, phone)

            session = self._get_session()
            resp = session.post(
                self._url('/payments/initiate'),
                json=payload,
                timeout=MOVAPAY_TIMEOUT,
            )
            resp.raise_for_status()
            data = resp.json()
            return {
                'success': True,
                'payment_url': data.get('payment_url', ''),
                'movapay_ref': data.get('transaction_id', ''),
                'message': data.get('message', 'Paiement initié avec succès.'),
                'raw': data,
            }
        except requests.exceptions.Timeout:
            logger.error("Movapay timeout for reference %s", reference)
            return {'success': False, 'message': 'Timeout de la passerelle de paiement.'}
        except requests.exceptions.RequestException as e:
            logger.error("Movapay error: %s", str(e))
            return {'success': False, 'message': f'Erreur Movapay: {str(e)}'}

    def verifier_paiement(self, reference: str, movapay_ref: str = '') -> dict:
        """
        Vérifie le statut d'une transaction.

        Returns:
            dict: {success, status, message, raw}
        """
        try:
            if is_sandbox_mode():
                return self._mock_verifier(reference)

            session = self._get_session()
            identifier = movapay_ref or reference
            resp = session.get(
                self._url(f'/payments/{identifier}/status'),
                timeout=MOVAPAY_TIMEOUT,
            )
            resp.raise_for_status()
            data = resp.json()
            movapay_status = data.get('status', 'unknown').lower()
            status_map = {
                'completed': 'success',
                'success': 'success',
                'paid': 'success',
                'failed': 'failed',
                'cancelled': 'cancelled',
                'pending': 'pending',
                'processing': 'pending',
            }
            return {
                'success': True,
                'status': status_map.get(movapay_status, 'pending'),
                'message': data.get('message', ''),
                'movapay_ref': data.get('transaction_id', movapay_ref),
                'raw': data,
            }
        except requests.exceptions.RequestException as e:
            logger.error("Movapay verify error: %s", str(e))
            return {'success': False, 'status': 'pending', 'message': str(e)}

    def rembourser(self, movapay_ref: str, montant: float = None) -> dict:
        """Initie un remboursement (partiel ou total)."""
        try:
            if is_sandbox_mode():
                return {'success': True, 'message': 'Remboursement sandbox simulé.'}

            session = self._get_session()
            payload = {'transaction_id': movapay_ref}
            if montant:
                payload['amount'] = str(montant)
            resp = session.post(
                self._url('/payments/refund'),
                json=payload,
                timeout=MOVAPAY_TIMEOUT,
            )
            resp.raise_for_status()
            return {'success': True, 'message': 'Remboursement initié.', 'raw': resp.json()}
        except requests.exceptions.RequestException as e:
            return {'success': False, 'message': str(e)}

    # ── Mocks sandbox ────────────────────────────────────────────────────────
    @staticmethod
    def _mock_initier(reference, montant, phone):
        mock_ref = f"MOCK_{uuid.uuid4().hex[:12].upper()}"
        return {
            'success': True,
            'payment_url': f'https://sandbox.movapay.com/pay/{mock_ref}',
            'movapay_ref': mock_ref,
            'message': f'[SANDBOX] Paiement initié — {montant} FCFA vers {phone}',
            'raw': {'sandbox': True, 'reference': reference},
        }

    @staticmethod
    def _mock_verifier(reference):
        return {
            'success': True,
            'status': 'success',
            'movapay_ref': f'MOCK_{reference[:8]}',
            'message': '[SANDBOX] Transaction confirmée.',
            'raw': {'sandbox': True},
        }


# Singleton
movapay_service = MovapayService()
