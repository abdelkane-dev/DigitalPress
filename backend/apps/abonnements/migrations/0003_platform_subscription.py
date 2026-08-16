from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("abonnements", "0002_plan_publisher"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="PlatformPlan",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("name", models.CharField(max_length=100)),
                ("description", models.TextField(blank=True)),
                ("prix", models.DecimalField(decimal_places=2, max_digits=10)),
                ("period", models.CharField(choices=[("monthly", "Mensuel"), ("quarterly", "Trimestriel"), ("yearly", "Annuel")], default="monthly", max_length=20)),
                ("features", models.TextField(blank=True, help_text="Fonctionnalités, une par ligne")),
                ("is_active", models.BooleanField(default=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
            ],
            options={
                "verbose_name": "Plan d'abonnement plateforme",
                "verbose_name_plural": "Plans d'abonnement plateforme",
                "ordering": ["prix"],
            },
        ),
        migrations.CreateModel(
            name="PublisherSubscription",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("montant", models.DecimalField(decimal_places=2, max_digits=10)),
                ("status", models.CharField(choices=[("active", "Actif"), ("expired", "Expiré"), ("cancelled", "Annulé"), ("pending", "En attente")], default="pending", max_length=20)),
                ("start_date", models.DateTimeField(blank=True, null=True)),
                ("end_date", models.DateTimeField(blank=True, null=True)),
                ("transaction_ref", models.CharField(blank=True, max_length=255)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("plan", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, to="abonnements.platformplan")),
                ("publisher", models.ForeignKey(limit_choices_to={"role": "publisher"}, on_delete=django.db.models.deletion.CASCADE, related_name="platform_subscriptions", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "verbose_name": "Abonnement plateforme éditeur",
                "verbose_name_plural": "Abonnements plateforme éditeurs",
                "ordering": ["-created_at"],
            },
        ),
    ]
