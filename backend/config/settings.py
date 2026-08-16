"""
Django settings — Digital Press Backend
"""
import os
from pathlib import Path
from datetime import timedelta
from dotenv import load_dotenv
import dj_database_url

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / '.env')

DEBUG = os.getenv('DEBUG', 'True') == 'True'

SECRET_KEY = os.getenv('SECRET_KEY', 'change-me-in-production-please')
if not DEBUG and SECRET_KEY == 'change-me-in-production-please':
    raise RuntimeError(
        'SECRET_KEY par défaut détectée avec DEBUG=False. '
        'Définissez une variable d\'environnement SECRET_KEY forte et unique avant le déploiement.'
    )

ALLOWED_HOSTS = ['*'] if DEBUG else os.getenv('ALLOWED_HOSTS', 'localhost,127.0.0.1').split(',')

# ─── SÉCURITÉ PRODUCTION ─────────────────────────────────────────────────────
# Activé uniquement quand DEBUG=False. Nginx gère le SSL en amont sur le VPS.
if not DEBUG:
    # Nginx termine le SSL — Django ne doit pas rediriger lui-même (boucle infinie)
    SECURE_SSL_REDIRECT = os.getenv('SECURE_SSL_REDIRECT', 'False') == 'True'
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_HSTS_SECONDS = int(os.getenv('SECURE_HSTS_SECONDS', '31536000'))
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True
    SECURE_CONTENT_TYPE_NOSNIFF = True
    SECURE_BROWSER_XSS_FILTER = True
    X_FRAME_OPTIONS = 'DENY'
    SECURE_REFERRER_POLICY = 'same-origin'
    # Permet de tourner correctement derrière Nginx (proxy inverse VPS)
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')

CSRF_TRUSTED_ORIGINS = [
    origin.strip() for origin in os.getenv('CSRF_TRUSTED_ORIGINS', '').split(',') if origin.strip()
]

# ─── APPLICATIONS ────────────────────────────────────────────────────────────
DJANGO_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
]

import importlib.util

THIRD_PARTY_APPS = [
    'rest_framework',
    'rest_framework_simplejwt',
    'rest_framework_simplejwt.token_blacklist',
    'corsheaders',
    'django_filters',
    'channels',
]

for app in ['drf_yasg', 'django_celery_beat', 'django_celery_results']:
    if importlib.util.find_spec(app.split('.')[0]) is not None:
        THIRD_PARTY_APPS.append(app)

LOCAL_APPS = [
    'apps.accounts',
    'apps.publications',
    'apps.abonnements',
    'apps.paiements',
    'apps.comptabilite',
    'apps.notifications',
    'apps.roadmap',
]

INSTALLED_APPS = DJANGO_APPS + THIRD_PARTY_APPS + LOCAL_APPS

# ─── MIDDLEWARE ───────────────────────────────────────────────────────────────
MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    # WhiteNoise : sert les fichiers statiques compressés (fallback si Nginx ne gère pas /static/)
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'config.urls'
AUTH_USER_MODEL = 'accounts.User'
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# ─── TEMPLATES ───────────────────────────────────────────────────────────────
TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'config.wsgi.application'

# ─── DATABASE (PostgreSQL) ───────────────────────────────────────────────────
# DATABASE_URL (format postgres://user:pass@host:port/db) — priorité si défini
_database_url = os.getenv('DATABASE_URL', '')
if _database_url:
    DATABASES = {
        'default': dj_database_url.parse(
            _database_url,
            conn_max_age=600,
            conn_health_checks=True,
        )
    }
else:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql',
            'NAME': os.getenv('DATABASE_NAME', 'digitalpress'),
            'USER': os.getenv('DATABASE_USER', 'dp_user'),
            'PASSWORD': os.getenv('DATABASE_PASSWORD', 'dp_pass'),
            'HOST': os.getenv('DATABASE_HOST', 'localhost'),
            'PORT': os.getenv('DATABASE_PORT', '5432'),
            'OPTIONS': {
                'connect_timeout': 10,
            },
        }
    }

# ─── CACHE / REDIS ───────────────────────────────────────────────────────────
# Cache mémoire locale (évite les erreurs d'incompatibilité avec Redis)
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
        'LOCATION': 'unique-snowflake',
    }
}

# ─── WEBSOCKETS / TEMPS RÉEL (Django Channels) ────────────────────────────────
ASGI_APPLICATION = 'config.asgi.application'

_ws_redis_url = os.getenv('REDIS_URL', 'redis://127.0.0.1:6379/1')
try:
    import redis
    r = redis.Redis.from_url(_ws_redis_url, socket_timeout=1)
    r.ping()
    CHANNEL_LAYERS = {
        'default': {
            'BACKEND': 'channels_redis.core.RedisChannelLayer',
            'CONFIG': {
                'hosts': [_ws_redis_url],
            },
        }
    }
except Exception:
    CHANNEL_LAYERS = {
        'default': {
            'BACKEND': 'channels.layers.InMemoryChannelLayer',
        }
    }

# ─── CELERY (PostgreSQL & Redis) ─────────────────────────────────────────────
REDIS_URL = os.getenv('REDIS_URL', 'redis://redis:6379/1')
CELERY_BROKER_URL = os.getenv('CELERY_BROKER_URL', REDIS_URL)
CELERY_RESULT_BACKEND = os.getenv('CELERY_RESULT_BACKEND', REDIS_URL)
CELERY_ACCEPT_CONTENT = ['json']
CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'
CELERY_TIMEZONE = 'Africa/Abidjan'
CELERY_TASK_TRACK_STARTED = True
CELERY_TASK_TIME_LIMIT = 30 * 60
CELERY_BEAT_SCHEDULER = 'django_celery_beat.schedulers:DatabaseScheduler'

try:
    from celery.schedules import crontab
    CELERY_BEAT_SCHEDULE = {
        'verifier-paiements-pending': {
            'task': 'apps.comptabilite.tasks.verifier_paiements_pending_batch',
            'schedule': crontab(minute='*/5'),
        },
        # Expiration des abonnements à minuit pile (00:00)
        'expirer-abonnements': {
            'task': 'apps.comptabilite.tasks.expirer_abonnements',
            'schedule': crontab(hour='0', minute='0'),
        },
        # Avertissement 3 jours avant expiration (00:30 chaque nuit)
        'notifier-expiration-proche': {
            'task': 'apps.comptabilite.tasks.notifier_expiration_proche',
            'schedule': crontab(hour='0', minute='30'),
        },
        # Expiration des mises en avant payantes « À la une » (00:15 chaque nuit)
        'expirer-mises-en-avant': {
            'task': 'apps.publications.tasks.expirer_mises_en_avant',
            'schedule': crontab(hour='0', minute='15'),
        },
        # Paiements automatiques aux éditeurs chaque nuit à 01:00
        'traiter-payouts-presse': {
            'task': 'apps.comptabilite.tasks.traiter_payouts_presse_automatique',
            'schedule': crontab(hour='1', minute='0'),
        },
        'nettoyer-transactions': {
            'task': 'apps.comptabilite.tasks.nettoyer_transactions_abandonnees',
            'schedule': crontab(hour='3', minute='0'),
        },
        'reconciliation-mensuelle': {
            'task': 'apps.comptabilite.tasks.calculer_reconciliation_mensuelle',
            'schedule': crontab(hour='1', minute='0', day_of_month='1'),
        },
    }
except ImportError:
    CELERY_BEAT_SCHEDULE = {}


# ─── REST FRAMEWORK ──────────────────────────────────────────────────────────
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
    'DEFAULT_FILTER_BACKENDS': [
        'django_filters.rest_framework.DjangoFilterBackend',
        'rest_framework.filters.SearchFilter',
        'rest_framework.filters.OrderingFilter',
    ],
    'DEFAULT_RENDERER_CLASSES': [
        'rest_framework.renderers.JSONRenderer',
    ],
    # Anti brute-force / anti-abus. Utilise le cache local (LocMemCache) défini
    # plus bas, donc ne nécessite pas Redis et peut rester actif partout.
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle',
        'rest_framework.throttling.ScopedRateThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {
        'anon': '60/minute',
        'user': '300/minute',
        'auth': '10/minute',
    },
    'EXCEPTION_HANDLER': 'core.exceptions.custom_exception_handler',
}

# ─── JWT ─────────────────────────────────────────────────────────────────────
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=int(os.getenv('JWT_ACCESS_MINUTES', '60'))),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=int(os.getenv('JWT_REFRESH_DAYS', '7'))),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
    'UPDATE_LAST_LOGIN': True,
    'ALGORITHM': 'HS256',
    'SIGNING_KEY': SECRET_KEY,
    'AUTH_HEADER_TYPES': ('Bearer',),
    'USER_ID_FIELD': 'id',
    'USER_ID_CLAIM': 'user_id',
}

# ─── CORS ────────────────────────────────────────────────────────────────────
def _parse_cors_origins():
    raw = os.getenv('CORS_ALLOWED_ORIGINS', '')
    return [
        origin.strip()
        for origin in raw.split(',')
        if origin.strip() and '://' in origin.strip()
    ]


# En dev (DEBUG=True) : toutes origines autorisées pour Flutter/Web
CORS_ALLOW_ALL_ORIGINS = DEBUG or os.getenv('CORS_ALLOW_ALL', 'False') == 'True'
CORS_ALLOWED_ORIGINS = [] if CORS_ALLOW_ALL_ORIGINS else _parse_cors_origins()
CORS_ALLOW_CREDENTIALS = True
CORS_ALLOW_HEADERS = [
    'accept', 'accept-encoding', 'authorization',
    'content-type', 'dnt', 'origin', 'user-agent',
    'x-csrftoken', 'x-requested-with',
]

# ─── SWAGGER / REDOC ─────────────────────────────────────────────────────────
SWAGGER_SETTINGS = {
    'SECURITY_DEFINITIONS': {
        'Bearer': {
            'type': 'apiKey',
            'name': 'Authorization',
            'in': 'header',
            'description': 'JWT Token. Format: **Bearer &lt;token&gt;**',
        }
    },
    'USE_SESSION_AUTH': False,
    'JSON_EDITOR': True,
    'SUPPORTED_SUBMIT_METHODS': ['get', 'post', 'put', 'patch', 'delete'],
    'DEFAULT_MODEL_RENDERING': 'example',
}

REDOC_SETTINGS = {
    'LAZY_RENDERING': False,
    'HIDE_HOSTNAME': False,
    'EXPAND_RESPONSES': '200,201',
}

# ─── STATIC / MEDIA ──────────────────────────────────────────────────────────
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
# WhiteNoise : compression + cache busting automatique en production
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

# Les fichiers média sont stockés dans le dossier media/ local
MEDIA_ROOT = BASE_DIR / 'media'

MEDIA_URL = '/media/'

# ─── INTERNATIONALISATION ────────────────────────────────────────────────────
LANGUAGE_CODE = 'fr-fr'
TIME_ZONE = 'Africa/Abidjan'
USE_I18N = True
USE_TZ = True

# ─── CINETPAY ───────────────────────────────────────────────────────────────
# Passerelle de paiement unifiée (mobile money + cartes, 40+ moyens,
# Afrique de l'Ouest et centrale) pour TOUS les rôles (lecteur, éditeur,
# admin). Les endpoints sont identiques en test et en production : il suffit
# de renseigner ces trois valeurs dans le .env pour basculer du mode
# simulation local vers la vraie passerelle (les identifiants de TEST de
# CinetPay acceptent de vraies cartes de tous les pays supportés).
CINETPAY_API_KEY = os.getenv('CINETPAY_API_KEY', '')
CINETPAY_SITE_ID = os.getenv('CINETPAY_SITE_ID', '')
CINETPAY_SECRET = os.getenv('CINETPAY_SECRET', '')
CINETPAY_BASE_URL = os.getenv('CINETPAY_BASE_URL', 'https://api-checkout.cinetpay.com/v2')

# ─── SMS (codes OTP de retrait — Twilio) ─────────────────────────────────────
# Fournisseur SMS réel pour le canal 'sms' des retraits (voir
# apps/paiements/sms.py, branché dans WithdrawalOtpView._deliver_sms). Tant
# que ces trois valeurs sont vides, le canal SMS reste en mode dev (le code
# est journalisé, jamais perdu) et l'email est le canal de livraison.
TWILIO_ACCOUNT_SID = os.getenv('TWILIO_ACCOUNT_SID', '')
TWILIO_AUTH_TOKEN = os.getenv('TWILIO_AUTH_TOKEN', '')
TWILIO_FROM_NUMBER = os.getenv('TWILIO_FROM_NUMBER', '')
# Indicatif pays par défaut utilisé pour normaliser un numéro local saisi
# sans préfixe (ex: '70 00 00 00' → '+223 70 00 00 00' pour le Mali).
TWILIO_DEFAULT_COUNTRY_CODE = os.getenv('TWILIO_DEFAULT_COUNTRY_CODE', '223')

# ─── EMAIL (codes de vérification, réinitialisation de mot de passe) ────────
# En dev : les emails s'affichent dans la console. En prod, configurez un SMTP
# réel (SendGrid, Mailgun, SES...) via les variables d'environnement.
EMAIL_BACKEND = os.getenv(
    'EMAIL_BACKEND',
    'django.core.mail.backends.console.EmailBackend' if DEBUG
    else 'django.core.mail.backends.smtp.EmailBackend',
)
EMAIL_HOST = os.getenv('EMAIL_HOST', 'localhost')
EMAIL_PORT = int(os.getenv('EMAIL_PORT', '587'))
EMAIL_HOST_USER = os.getenv('EMAIL_HOST_USER', '')
EMAIL_HOST_PASSWORD = os.getenv('EMAIL_HOST_PASSWORD', '')
EMAIL_USE_TLS = os.getenv('EMAIL_USE_TLS', 'True') == 'True'
DEFAULT_FROM_EMAIL = os.getenv('DEFAULT_FROM_EMAIL', 'no-reply@digitalpress.local')

# ─── CONNEXION GOOGLE / FACEBOOK (voir accounts.GoogleAuthView/FacebookAuthView) ─
# GOOGLE_OAUTH_CLIENT_ID : le "Client ID Web" créé dans Google Cloud
# Console pour ce projet Firebase (Identifiants > Créer des identifiants >
# ID client OAuth > Application Web). PAS le client ID Android/iOS.
GOOGLE_OAUTH_CLIENT_ID = os.getenv('GOOGLE_OAUTH_CLIENT_ID', '')
# FACEBOOK_APP_ID / FACEBOOK_APP_SECRET : depuis developers.facebook.com,
# dans les réglages de base de votre application Facebook.
FACEBOOK_APP_ID = os.getenv('FACEBOOK_APP_ID', '')
FACEBOOK_APP_SECRET = os.getenv('FACEBOOK_APP_SECRET', '')

# ─── MISC ────────────────────────────────────────────────────────────────────
BACKEND_URL = os.getenv('BACKEND_URL', 'http://localhost:8000')
FRONTEND_SUCCESS_URL = os.getenv('FRONTEND_SUCCESS_URL', 'http://localhost:3000/payment/success')

# Créer le dossier logs/ s'il n'existe pas (évite FileNotFoundError au démarrage)
_logs_dir = BASE_DIR / 'logs'
_logs_dir.mkdir(exist_ok=True)

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {'format': '{levelname} {asctime} {module} {message}', 'style': '{'},
        'simple': {'format': '{levelname} {message}', 'style': '{'},
    },
    'handlers': {
        'console': {'class': 'logging.StreamHandler', 'formatter': 'verbose'},
        'file': {
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': str(_logs_dir / 'django.log'),
            'maxBytes': 1024 * 1024 * 5,
            'backupCount': 5,
            'formatter': 'verbose',
        },
    },
    'root': {'handlers': ['console'], 'level': 'INFO'},
    'loggers': {
        'django': {
            'handlers': ['console', 'file'],
            'level': 'WARNING',
            'propagate': False,
        },
        'apps': {
            'handlers': ['console', 'file'],
            'level': 'DEBUG',
            'propagate': False,
        },
    },
}