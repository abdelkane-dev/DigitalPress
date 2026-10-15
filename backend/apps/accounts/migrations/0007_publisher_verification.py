from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0006_add_email_unique_billing_fields_notifpref"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="PublisherVerification",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("legal_company_name", models.CharField(help_text="Raison sociale exacte", max_length=255)),
                ("registration_number", models.CharField(help_text="Numéro RCCM / registre du commerce (ou équivalent local)", max_length=100)),
                ("tax_id", models.CharField(help_text="NIF / numéro d'identification fiscale", max_length=100)),
                ("official_address", models.TextField(help_text="Adresse physique complète du siège")),
                ("city", models.CharField(max_length=100)),
                ("country", models.CharField(max_length=100)),
                ("phone_number", models.CharField(max_length=30)),
                ("legal_representative_name", models.CharField(max_length=255)),
                ("legal_representative_id_number", models.CharField(help_text="N° CNI / passeport du représentant légal", max_length=100)),
                ("press_accreditation_number", models.CharField(blank=True, help_text="N° d'accréditation presse / conseil de presse, si applicable", max_length=100)),
                ("website", models.URLField(blank=True)),
                ("id_document_url", models.URLField(help_text="Pièce d'identité du représentant légal")),
                ("registration_document_url", models.URLField(help_text="Certificat RCCM / registre du commerce")),
                ("additional_document_url", models.URLField(blank=True, help_text="Licence de presse ou autre justificatif")),
                ("status", models.CharField(choices=[("pending", "En attente de vérification"), ("approved", "Validée"), ("rejected", "Rejetée")], default="pending", max_length=20)),
                ("rejection_reason", models.TextField(blank=True)),
                ("submitted_at", models.DateTimeField(auto_now_add=True)),
                ("reviewed_at", models.DateTimeField(blank=True, null=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("reviewed_by", models.ForeignKey(blank=True, limit_choices_to={"role": "admin"}, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="verifications_reviewed", to=settings.AUTH_USER_MODEL)),
                ("user", models.OneToOneField(limit_choices_to={"role": "publisher"}, on_delete=django.db.models.deletion.CASCADE, related_name="verification", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "verbose_name": "Vérification d'éditeur",
                "verbose_name_plural": "Vérifications d'éditeurs",
                "ordering": ["-submitted_at"],
            },
        ),
    ]
