import os

# Celery uniquement en mode PostgreSQL / production
if os.getenv('USE_SQLITE', 'True') != 'True':
    from .celery import app as celery_app
    __all__ = ('celery_app',)
else:
    # Mode SQLite : Celery désactivé
    __all__ = ()