from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("accounts", "0002_user_solde"),
    ]

    operations = [
        migrations.CreateModel(
            name="PosterWarning",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("reason", models.TextField()),
                ("severity", models.CharField(choices=[("info", "Information"), ("warning", "Avertissement"), ("critical", "Critique")], default="warning", max_length=20)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("issued_by", models.ForeignKey(null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="warnings_issued", to=settings.AUTH_USER_MODEL)),
                ("publisher", models.ForeignKey(limit_choices_to={"role": "publisher"}, on_delete=django.db.models.deletion.CASCADE, related_name="warnings_received", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "verbose_name": "Avertissement éditeur",
                "verbose_name_plural": "Avertissements éditeurs",
                "ordering": ["-created_at"],
            },
        ),
        migrations.CreateModel(
            name="PasswordResetCode",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("code_hash", models.CharField(max_length=64)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("expires_at", models.DateTimeField()),
                ("is_used", models.BooleanField(default=False)),
                ("attempts", models.PositiveSmallIntegerField(default=0)),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="password_reset_codes", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "verbose_name": "Code de réinitialisation",
                "verbose_name_plural": "Codes de réinitialisation",
                "ordering": ["-created_at"],
            },
        ),
    ]
