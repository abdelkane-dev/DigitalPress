from django.apps import AppConfig


class RoadmapConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'apps.roadmap'

    def ready(self):
        import apps.roadmap.signals  # noqa: F401
