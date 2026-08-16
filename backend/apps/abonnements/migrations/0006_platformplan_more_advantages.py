from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("abonnements", "0005_seed_default_plans"),
    ]

    operations = [
        migrations.AddField(
            model_name="platformplan",
            name="commission_rate",
            field=models.DecimalField(
                decimal_places=2, default=10.00, max_digits=5,
                help_text="Taux de commission plateforme sur les ventes (%) — plus bas = l'éditeur garde plus d'argent",
            ),
        ),
        migrations.AddField(
            model_name="platformplan",
            name="max_reader_plans",
            field=models.PositiveIntegerField(
                default=3,
                help_text="Nombre d'offres d'abonnement (Lecteur→Éditeur) que l'éditeur peut créer (0 = illimité)",
            ),
        ),
        migrations.AddField(
            model_name="platformplan",
            name="has_verified_badge",
            field=models.BooleanField(
                default=False, help_text="Badge « Vérifié » affiché sur le profil public de l'éditeur",
            ),
        ),
        migrations.AddField(
            model_name="platformplan",
            name="min_withdrawal_amount",
            field=models.DecimalField(
                decimal_places=2, default=10000, max_digits=10,
                help_text="Montant minimum autorisé par demande de retrait — plus bas = plus de flexibilité",
            ),
        ),
        migrations.AddField(
            model_name="platformplan",
            name="has_stats_export",
            field=models.BooleanField(
                default=False, help_text="Autorise l'export CSV des statistiques détaillées",
            ),
        ),
    ]
