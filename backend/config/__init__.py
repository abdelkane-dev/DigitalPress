# Celery est toujours actif : DigitalPress n'utilise que PostgreSQL
# (le broker Redis est requis, voir .env.example).
from .celery import app as celery_app

__all__ = ('celery_app',)
