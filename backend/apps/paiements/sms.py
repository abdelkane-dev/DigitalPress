"""Fournisseur SMS transactionnel (codes OTP de retrait).

Point de branchement unique du canal SMS des retraits (voir
`apps/paiements/views.py::WithdrawalOtpView._deliver_sms`). Implémentation
actuelle : **Twilio** via son API REST appelée directement avec `requests`
(déjà dans requirements.txt) — volontairement pas de dépendance SDK
supplémentaire pour ne rien installer sur le VPS.

Activation : le canal SMS n'émet des SMS réels que lorsque les trois clés
Twilio sont renseignées dans le .env (TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN,
TWILIO_FROM_NUMBER). Tant qu'elles sont vides, le code est journalisé (mode
dev, comportement historique) et l'email reste le canal de livraison
principal — le flux de retrait ne casse jamais.
"""
import logging

from django.conf import settings

logger = logging.getLogger('apps')


def sms_provider_configured() -> bool:
    """True si toutes les clés Twilio nécessaires sont présentes dans le
    .env — c'est ce qui bascule le canal SMS du mode dev (journalisé) vers
    l'envoi réel."""
    return bool(
        getattr(settings, 'TWILIO_ACCOUNT_SID', '')
        and getattr(settings, 'TWILIO_AUTH_TOKEN', '')
        and getattr(settings, 'TWILIO_FROM_NUMBER', '')
    )


def normalize_phone(phone: str) -> str:
    """Normalise un numéro local vers le format E.164 exigé par Twilio.

    - '+223 70 00 00 00'  → '+22370000000'
    - '70 00 00 00'       → '+22370000000' (indicatif par défaut
      configurable via TWILIO_DEFAULT_COUNTRY_CODE, 223 = Mali)
    - '+221 77 123 45 67' → '+221771234567' (indicatif déjà présent
      conservé tel quel)
    """
    digits = ''.join(ch for ch in phone if ch.isdigit() or ch == '+')
    if digits.startswith('+'):
        return digits
    country = getattr(settings, 'TWILIO_DEFAULT_COUNTRY_CODE', '223').lstrip('+')
    return f'+{country}{digits}'


def send_sms(to_phone: str, message: str) -> bool:
    """Envoie un SMS via l'API REST Twilio (Messages).

    Lève une exception si Twilio refuse (mauvaises clés, numéro invalide,
    solde insuffisant...) : l'appelant décide du comportement de repli
    (ici : journaliser et laisser l'email faire foi).
    """
    import requests

    sid = settings.TWILIO_ACCOUNT_SID
    token = settings.TWILIO_AUTH_TOKEN
    from_number = settings.TWILIO_FROM_NUMBER

    response = requests.post(
        f'https://api.twilio.com/2010-04-01/Accounts/{sid}/Messages.json',
        auth=(sid, token),
        data={
            'From': from_number,
            'To': to_phone,
            'Body': message,
        },
        timeout=15,
    )
    response.raise_for_status()
    logger.info('[SMS OTP retrait] envoyé à %s (sid=%s)', to_phone, response.json().get('sid', ''))
    return True


def send_withdrawal_otp(user, raw_code: str) -> bool:
    """Envoie le code OTP de retrait par SMS à l'utilisateur.

    Retourne True si un SMS réel a été émis, False si le fournisseur n'est
    pas configuré (code journalisé en dev) ou si l'utilisateur n'a pas de
    numéro de téléphone — dans les deux cas l'email envoyé en parallèle par
    WithdrawalOtpView reste le canal de livraison.
    """
    if not sms_provider_configured():
        logger.info(
            "[SMS OTP retrait] destinataire=%s code=%s (fournisseur SMS non "
            "configuré — email envoyé en parallèle)",
            user.phone or user.email,
            raw_code,
        )
        return False

    if not user.phone:
        logger.warning(
            "[SMS OTP retrait] utilisateur %s sans numéro de téléphone — "
            "code %s livré uniquement par email",
            user.email,
            raw_code,
        )
        return False

    message = (
        f"DigitalPress : votre code de confirmation de retrait est {raw_code}. "
        f"Il expire dans 15 minutes. Ne le communiquez à personne."
    )
    return send_sms(normalize_phone(user.phone), message)
