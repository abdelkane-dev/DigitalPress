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

# Détection automatique de l'environnement Render
IS_RENDER = os.getenv('RENDER', 'False') == 'True'

DEBUG = os.getenv('DEBUG', 'True') == 'True'

SECRET_KEY = os.getenv('SECRET_KEY', 'change-me-in-production-please')
if not DEBUG and SECRET_KEY == 'change-me-in-production-please':
    raise RuntimeError(
        'SECRET_KEY par défaut détectée avec DEBUG=False. '
        'Définissez une variable d\'environnement SECRET_KEY forte et unique avant le déploiement.'
    )

_base_hosts = ['*'] if DEBUG else os.getenv('ALLOWED_HOSTS', 'localhost,127.0.0.1').split(',')
# Ajoute automatiquement le hostname public Render (ex: digitalpress-api.onrender.com)
_render_host = os.getenv('RENDER_EXTERNAL_HOSTNAME', '')
ALLOWED_HOSTS = list(set(_base_hosts + ([_render_host] if _render_host else [])))

# ─── SÉCURITÉ PRODUCTION ─────────────────────────────────────────────────────
# Activé uniquement quand DEBUG=False, pour ne jamais gêner le développement local.
if not DEBUG:
    # Render gère le SSL en amont (proxy) — ne pas rediriger ici sinon boucle infinie
    SECURE_SSL_REDIRECT = False if IS_RENDER else (os.getenv('SECURE_SSL_REDIRECT', 'True') == 'True')
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_HSTS_SECONDS = int(os.getenv('SECURE_HSTS_SECONDS', '31536000'))
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True
    SECURE_CONTENT_TYPE_NOSNIFF = True
    SECURE_BROWSER_XSS_FILTER = True
    X_FRAME_OPTIONS = 'DENY'
    SECURE_REFERRER_POLICY = 'same-origin'
    # Permet de tourner correctement derrière un proxy/LB (Nginx, Render, etc.)
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')

CSRF_TRUSTED_ORIGINS = [
    origin.strip() for origin in os.getenv('CSRF_TRUSTED_ORIGINS', '').split(',') if origin.strip()
]

# ─── MODE BASE DE DONNÉES ──────────────────────────────────────────────────────
USE_SQLITE = os.getenv('USE_SQLITE', 'True') == 'True'

# ─── APPLICATIONS ────────────────────────────────────────────────────────────
DJANGO_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
]

THIRD_PARTY_APPS = [
    'rest_framework',
    'rest_framework_simplejwt',
    'rest_framework_simplejwt.token_blacklist',
    'corsheaders',
    'django_filters',
]

if not USE_SQLITE:
    THIRD_PARTY_APPS += [
        'drf_yasg',
        'django_celery_beat',
        'django_celery_results',
    ]

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
    # WhiteNoise : sert les fichiers statiques sans Nginx (requis sur Render)
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

# ─── DATABASE ────────────────────────────────────────────────────────────────
if USE_SQLITE:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': BASE_DIR / 'db.sqlite3',
        }
    }
else:
    # Sur Render, DATABASE_URL est injecté automatiquement — priorité absolue
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

# ─── CELERY (production PostgreSQL) ───────────────────────────────────────────
if not USE_SQLITE:
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


# En dev Docker (DEBUG=True) : toutes origines autorisées pour Flutter/Web
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

# Les fichiers média sont stockés dans le dossier media/ local (éphémère sur Render gratuit)
MEDIA_ROOT = BASE_DIR / 'media'

MEDIA_URL = '/media/'

# ─── INTERNATIONALISATION ────────────────────────────────────────────────────
LANGUAGE_CODE = 'fr-fr'
TIME_ZONE = 'Africa/Abidjan'
USE_I18N = True
USE_TZ = True

# ─── MOVAPAY ─────────────────────────────────────────────────────────────────
MOVAPAY_API_KEY = os.getenv('MOVAPAY_API_KEY', '')
MOVAPAY_SECRET = os.getenv('MOVAPAY_SECRET', '')
MOVAPAY_BASE_URL = os.getenv('MOVAPAY_BASE_URL', 'https://api.movapay.com/v1')

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

# ─── MISC ────────────────────────────────────────────────────────────────────
BACKEND_URL = os.getenv('BACKEND_URL', 'http://localhost:8000')
FRONTEND_SUCCESS_URL = os.getenv('FRONTEND_SUCCESS_URL', 'http://localhost:3000/payment/success')

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
            'filename': BASE_DIR / 'logs' / 'django.log',
            'maxBytes': 1024 * 1024 * 5,
            'backupCount': 5,
            'formatter': 'verbose',
        },
    },
    'root': {'handlers': ['console'], 'level': 'INFO'},
    'loggers': {
        'django': {
            'handlers': ['console'] if USE_SQLITE else ['console', 'file'],
            'level': 'WARNING',
            'propagate': False,
        },
        'apps': {
            'handlers': ['console'] if USE_SQLITE else ['console', 'file'],
            'level': 'DEBUG',
            'propagate': False,
        },
    },
}