from django.apps import AppConfig


class AbonnementsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'apps.abonnements'

    def ready(self):
        import apps.abonnements.signals  # noqa: F401
