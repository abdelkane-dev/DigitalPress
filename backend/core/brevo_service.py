"""Service centralisé Brevo (Sendinblue) pour Emails et SMS transactionnels.

Prend en charge :
1. Envoi de SMS transactionnels via l'API REST v3 de Brevo.
2. Envoi d'Emails transactionnels via SMTP Django ou l'API REST v3 de Brevo.
"""
import logging
import requests
from django.conf import settings
from django.core.mail import send_mail

logger = logging.getLogger('apps')

BREVO_API_URL = 'https://api.brevo.com/v3'


def send_brevo_sms(recipient_phone: str, content: str, sender: str = None) -> bool:
    """Envoie un SMS transactionnel via l'API REST Brevo v3.

    Args:
        recipient_phone: Numéro de téléphone au format international (ex: +22370000000)
        content: Texte du message (max 160 caractères recommandé)
        sender: Nom de l'expéditeur alphanumérique (11 car. max, ex: 'DigitalPress')
    """
    api_key = getattr(settings, 'BREVO_API_KEY', '')
    if not api_key:
        logger.warning("BREVO_API_KEY non configurée. SMS non envoyé à %s", recipient_phone)
        return False

    sender_name = sender or getattr(settings, 'BREVO_SMS_SENDER', 'DigitalPress')[:11]

    # Normalisation du numéro de téléphone
    phone = recipient_phone.strip().replace(' ', '').replace('-', '')
    if not phone.startswith('+'):
        default_code = getattr(settings, 'TWILIO_DEFAULT_COUNTRY_CODE', '223')
        if not phone.startswith(default_code):
            phone = f'+{default_code}{phone}'
        else:
            phone = f'+{phone}'

    payload = {
        'sender': sender_name,
        'recipient': phone,
        'content': content,
        'type': 'transactional',
    }

    headers = {
        'api-key': api_key,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
    }

    try:
        response = requests.post(
            f"{BREVO_API_URL}/transactionalSMS/sendTransacSms",
            json=payload,
            headers=headers,
            timeout=10,
        )
        if response.status_code in (200, 201):
            logger.info("SMS Brevo envoyé avec succès à %s (ID: %s)", phone, response.json().get('messageId'))
            return True
        else:
            logger.error("Échec envoi SMS Brevo à %s (Status %s): %s", phone, response.status_code, response.text)
            return False
    except Exception as e:
        logger.exception("Erreur lors de l'appel API SMS Brevo: %s", e)
        return False


def send_brevo_email(to_email: str, subject: str, message: str, html_message: str = None) -> bool:
    """Envoie un email transactionnel via le SMTP configuré (Brevo)."""
    try:
        from_email = getattr(settings, 'DEFAULT_FROM_EMAIL', 'support@digitalpress-ml.com')
        send_mail(
            subject=subject,
            message=message,
            from_email=from_email,
            recipient_list=[to_email],
            html_message=html_message,
            fail_silently=False,
        )
        logger.info("Email envoyé avec succès à %s", to_email)
        return True
    except Exception as e:
        logger.exception("Échec de l'envoi de l'email à %s: %s", to_email, e)
        return False
