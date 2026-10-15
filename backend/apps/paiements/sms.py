"""Fournisseur de notifications OTP (retraits).

À partir de cette version, TOUS les codes OTP sont envoyés par EMAIL
via Brevo (SMTP). Les fournisseurs SMS legacy (Twilio, Africa's Talking,
Orange Mali) ont été supprimés pour simplifier la maintenance et réduire
les coûts — Brevo offre 300 emails/jour gratuits, largement suffisant.

Le canal email est le canal PRINCIPAL et UNIQUE pour les codes OTP.
"""
import logging

from django.conf import settings

logger = logging.getLogger('apps')


def _get_provider() -> str:
    """Toujours 'email' — le seul canal de livraison."""
    return 'email'


def sms_provider_configured() -> bool:
    """True si Brevo SMTP est configuré (EMAIL_HOST_USER + EMAIL_HOST_PASSWORD)."""
    return bool(
        getattr(settings, 'EMAIL_HOST_USER', '')
        and getattr(settings, 'EMAIL_HOST_PASSWORD', '')
    )


def normalize_phone(phone: str) -> str:
    """Normalise un numéro local vers le format E.164.

    Conservé pour compatibilité avec le reste du codebase, mais
    le numéro n'est plus utilisé pour envoyer des SMS.
    """
    digits = ''.join(ch for ch in phone if ch.isdigit() or ch == '+')
    if digits.startswith('+'):
        return digits
    country = '223'
    return f'+{country}{digits}'


def send_sms(to_phone: str, message: str) -> bool:
    """Désactivé — tous les OTP sont envoyés par email via Brevo.

    Ce stub existe pour éviter les erreurs d'import dans le reste
    du codebase. Il journalise l'appel et retourne False.
    """
    logger.info(
        "[SMS désactivé] OTP non envoyé par SMS à %s — canal email Brevo utilisé à la place",
        to_phone,
    )
    return False


def send_withdrawal_otp(user, raw_code: str) -> bool:
    """Envoie le code OTP de retrait par email (Brevo SMTP).

    Le SMS est désactivé. L'email est envoyé en parallèle par
    WithdrawalOtpView. Ce retour indique si un SMS réel aurait été
    envoyé (jamais, désormais).
    """
    if not sms_provider_configured():
        logger.info(
            "[OTP retrait] destinataire=%s code=%s (Brevo SMTP non configuré — "
            "code journalisé uniquement)",
            user.email,
            raw_code,
        )
        return False

    logger.info(
        "[OTP retrait] code envoyé par email Brevo à %s (SMS désactivé)",
        user.email,
    )
    return False
