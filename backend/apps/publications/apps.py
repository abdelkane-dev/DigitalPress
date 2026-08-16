from django.apps import AppConfig


class PublicationsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'apps.publications'

    def ready(self):
        import apps.publications.signals  # noqa: F401
