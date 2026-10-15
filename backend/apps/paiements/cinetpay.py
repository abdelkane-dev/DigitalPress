"""
Service d'intégration CinetPay — passerelle de paiement unifiée pour toute
l'app (lecteur, éditeur, admin). CinetPay agrège 40+ moyens de paiement
(mobile money : Orange Money, Moov Money, MTN MoMo, Wave... + cartes
bancaires Visa/Mastercard/AMEX) sur 9+ pays d'Afrique de l'Ouest et
centrale.

Documentation officielle :
  - Initiation :  https://docs.cinetpay.com/api/1.0-en/checkout/initialisation
  - Vérification : https://docs.cinetpay.com/api/1.0-en/checkout/verification
  - Notification : https://docs.cinetpay.com/api/1.0-en/checkout/notification

Mode réel : POST https://api-checkout.cinetpay.com/v2/payment   (initiation)
            POST https://api-checkout.cinetpay.com/v2/payment/check (statut)
Mode sandbox : les MÊMES endpoints avec les identifiants de TEST du
  marchand (apikey + site_id de test fournis par CinetPay). Le site de test
  de CinetPay accepte de vraies cartes aux formats réels de tous les pays
  supportés pour valider le parcours de paiement.
Mode simulation (défaut si aucune clé réelle dans .env) : mock local,
  tout le parcours fonctionne en dev sans réseau — les vraies clés/URLs
  seront branchées simplement en remplissant le .env de production.
"""
import hashlib
import hmac
import uuid
import logging
import requests
from django.conf import settings

logger = logging.getLogger(__name__)

CINETPAY_BASE_URL = getattr(
    settings, 'CINETPAY_BASE_URL', 'https://api-checkout.cinetpay.com/v2'
)
CINETPAY_API_KEY = getattr(settings, 'CINETPAY_API_KEY', '')
CINETPAY_SITE_ID = getattr(settings, 'CINETPAY_SITE_ID', '')
CINETPAY_SECRET = getattr(settings, 'CINETPAY_SECRET', '')
CINETPAY_TIMEOUT = 30  # secondes

_PLACEHOLDER_VALUES = (
    '', 'YOUR_CINETPAY_KEY', 'YOUR_CINETPAY_API_KEY', 'YOUR_CINETPAY_SECRET',
    'your_api_key_here', 'votre_cle_api',
)


def is_sandbox_mode() -> bool:
    """Vrai si aucune clé CinetPay réelle n'est configurée (mode démo/local).

    Le passage en production réelle se fait uniquement en remplissant
    CINETPAY_API_KEY / CINETPAY_SITE_ID / CINETPAY_SECRET dans le .env —
    aucun changement de code n'est nécessaire (les endpoints sont les mêmes
    en test et en production).
    """
    key = getattr(settings, 'CINETPAY_API_KEY', '')
    site = getattr(settings, 'CINETPAY_SITE_ID', '')
    return (not key or key in _PLACEHOLDER_VALUES) or (not site or site in _PLACEHOLDER_VALUES)


def verify_webhook_signature(raw_body: bytes, signature_header: str) -> bool:
    """Vérifie la signature HMAC-SHA512 d'un webhook CinetPay.

    CinetPay signe chaque notification avec la clé secrète du compte
    marchand ; le webhook doit reproduire ce calcul et comparer les deux
    signatures de façon résistante aux attaques temporelles
    (`hmac.compare_digest`). Sans cette vérification, n'importe qui pouvait
    appeler `/api/paiements/webhook/` (accessible sans authentification,
    comme l'exige un vrai webhook) avec un statut « ACCEPTED » fabriqué et
    créditer frauduleusement n'importe quel compte.

    ⚠️ La vérification HMAC ne dispense JAMAIS d'appeler l'API de
    vérification (`/v2/payment/check`) pour confirmer le statut réel de la
    transaction côté CinetPay (voir WebhookView).

    En mode sandbox (aucune clé réelle configurée), la vérification est
    ignorée pour permettre les tests locaux avec le service simulé.
    """
    if is_sandbox_mode():
        logger.warning(
            "Webhook CinetPay reçu en mode sandbox : signature non vérifiée "
            "(aucune clé CinetPay réelle configurée)."
        )
        return True

    secret = getattr(settings, 'CINETPAY_SECRET', '')
    if not signature_header or not secret:
        return False

    expected = hmac.new(
        secret.encode('utf-8'), raw_body, hashlib.sha512
    ).hexdigest()
    return hmac.compare_digest(expected, signature_header)


class CinetPayService:
    """Client HTTP pour l'API CinetPay (v2, checkout hébergé)."""

    @property
    def base_url(self) -> str:
        return getattr(
            settings, 'CINETPAY_BASE_URL', 'https://api-checkout.cinetpay.com/v2'
        )

    @property
    def api_key(self) -> str:
        return getattr(settings, 'CINETPAY_API_KEY', '')

    @property
    def site_id(self) -> str:
        return getattr(settings, 'CINETPAY_SITE_ID', '')

    def _url(self, endpoint: str) -> str:
        return f"{self.base_url.rstrip('/')}/{endpoint.lstrip('/')}"

    def _payload_base(self, reference: str) -> dict:
        return {
            'apikey': self.api_key,
            'site_id': self.site_id,
            'transaction_id': reference,
        }

    def initier_paiement(
        self,
        montant: float,
        reference: str,
        description: str = '',
        phone: str = '',
        email: str = '',
        customer_name: str = '',
        channels: str = 'ALL',
        currency: str = 'XOF',
    ) -> dict:
        """Initie une transaction CinetPay (checkout hébergé).

        Args:
            channels: 'ALL' (mobile money + carte), 'MOBILE' (mobile money
                uniquement) ou 'CARD' (carte bancaire uniquement).

        Returns:
            dict: {success, payment_url, cinetpay_token, message}
        """
        # Transaction_id CinetPay : alphanumérique, sans caractères spéciaux.
        tx_id = reference.replace('-', '').replace('_', '')[:36]
        payload = {
            'apikey': self.api_key,
            'site_id': self.site_id,
            'transaction_id': tx_id,
            'amount': str(int(montant)),
            'currency': currency,
            'description': (description or f'Digital Press — {reference}')[:255],
            'notify_url': f"{getattr(settings, 'BACKEND_URL', 'http://localhost:8000')}/api/paiements/webhook/",
            'return_url': getattr(settings, 'FRONTEND_SUCCESS_URL', 'http://localhost:8000/payment/success'),
            'channels': channels,
            'lang': 'FR',
            'customer': {
                'name': customer_name or 'Client',
                'surname': '',
                'email': email or 'client@digitalpress.local',
                'phone_number': phone or '',
                'address': '',
                'city': '',
                'country': '',
                'state': '',
                'zip_code': '',
            },
        }
        try:
            if is_sandbox_mode():
                logger.warning(
                    "Clés CinetPay non configurées — mode simulation local "
                    "(le paiement sera marqué succès sans passerelle réelle)."
                )
                return self._mock_initier(reference, montant, phone)

            resp = requests.post(
                self._url('/payment'),
                json=payload,
                timeout=CINETPAY_TIMEOUT,
            )
            resp.raise_for_status()
            data = resp.json()
            if data.get('code') != '00':
                logger.error(
                    "CinetPay init error code=%s message=%s description=%s",
                    data.get('code'), data.get('message'), data.get('description'),
                )
                return {
                    'success': False,
                    'message': data.get('description') or data.get('message') or 'Erreur CinetPay.',
                    'raw': data,
                }
            d = data.get('data', {}) or {}
            return {
                'success': True,
                'payment_url': d.get('payment_url', ''),
                'cinetpay_token': d.get('token', ''),
                'cinetpay_ref': tx_id,
                'message': 'Paiement initié avec succès.',
                'raw': data,
            }
        except requests.exceptions.Timeout:
            logger.error("CinetPay timeout for reference %s", reference)
            return {'success': False, 'message': 'Timeout de la passerelle de paiement.'}
        except requests.exceptions.RequestException as e:
            logger.error("CinetPay error: %s", str(e))
            return {'success': False, 'message': f'Erreur CinetPay: {str(e)}'}

    def verifier_paiement(self, reference: str) -> dict:
        """Vérifie le statut réel d'une transaction auprès de CinetPay.

        C'est CET appel (et non les données du webhook) qui fait foi pour
        créditer un compte : les statuts `cpm_trans_status` renvoyés sont
        VALIDATED / REFUSED / CANCELLED / PENDING...

        Returns:
            dict: {success, status, message, cinetpay_ref, raw}
                status ∈ {'success', 'failed', 'cancelled', 'pending'}
        """
        try:
            if is_sandbox_mode():
                return self._mock_verifier(reference)

            tx_id = reference.replace('-', '').replace('_', '')[:36]
            payload = self._payload_base(tx_id)
            resp = requests.post(
                self._url('/payment/check'),
                json=payload,
                timeout=CINETPAY_TIMEOUT,
            )
            resp.raise_for_status()
            data = resp.json()
            if data.get('code') != '00':
                logger.error(
                    "CinetPay check error code=%s message=%s",
                    data.get('code'), data.get('message'),
                )
                return {'success': False, 'status': 'pending', 'message': data.get('message', '')}
            d = data.get('data', {}) or {}
            cpm_status = (d.get('cpm_trans_status') or '').upper()
            status_map = {
                'VALIDATED': 'success',
                'ACCEPTED': 'success',
                'SUCCESS': 'success',
                'REFUSED': 'failed',
                'FAILED': 'failed',
                'CANCELLED': 'cancelled',
                'CANCELED': 'cancelled',
                'PENDING': 'pending',
                'CREATED': 'pending',
                'EXPIRED': 'failed',
            }
            return {
                'success': True,
                'status': status_map.get(cpm_status, 'pending'),
                'message': d.get('cpm_error_message', ''),
                'cinetpay_ref': d.get('cpm_trans_id', ''),
                'raw': data,
            }
        except requests.exceptions.RequestException as e:
            logger.error("CinetPay verify error: %s", str(e))
            return {'success': False, 'status': 'pending', 'message': str(e)}

    def rembourser(self, reference: str) -> dict:
        """Remboursement : non supporté par l'API checkout v2 publique —
        à effectuer depuis le tableau de bord marchand CinetPay."""
        return {
            'success': False,
            'message': 'Remboursement à effectuer depuis le tableau de bord marchand CinetPay.',
        }

    # ── Simulation locale (aucune clé CinetPay configurée) ─────────────────
    # Tout le parcours de paiement fonctionne en dev : l'initiation renvoie
    # une URL factice, la vérification renvoie systématiquement « success ».
    # En production, remplir le .env (CINETPAY_API_KEY / SITE_ID / SECRET)
    # pour basculer automatiquement sur la vraie passerelle — y compris en
    # mode test CinetPay avec les cartes de test des différents pays.
    @staticmethod
    def _mock_initier(reference, montant, phone):
        mock_ref = f"MOCK_{uuid.uuid4().hex[:12].upper()}"
        return {
            'success': True,
            'payment_url': f'https://sandbox.cinetpay.com/checkout/{mock_ref}',
            'cinetpay_token': mock_ref,
            'cinetpay_ref': mock_ref,
            'message': f'[SIMULATION] Paiement initié — {int(montant)} FCFA vers {phone or "portefeuille"}',
            'raw': {'sandbox': True, 'reference': reference},
        }

    @staticmethod
    def _mock_verifier(reference):
        return {
            'success': True,
            'status': 'success',
            'cinetpay_ref': f'MOCK_{reference[:8]}',
            'message': '[SIMULATION] Transaction confirmée.',
            'raw': {'sandbox': True},
        }


# Singleton
cinetpay_service = CinetPayService()
