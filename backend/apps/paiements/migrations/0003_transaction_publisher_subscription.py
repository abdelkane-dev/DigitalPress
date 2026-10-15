from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("abonnements", "0003_platform_subscription"),
        ("paiements", "0002_alter_transaction_type_transaction"),
    ]

    operations = [
        migrations.AddField(
            model_name="transaction",
            name="publisher_subscription",
            field=models.ForeignKey(
                blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL,
                related_name="transactions", to="abonnements.publishersubscription",
            ),
        ),
        migrations.AlterField(
            model_name="transaction",
            name="type_transaction",
            field=models.CharField(
                choices=[
                    ("subscription", "Abonnement"),
                    ("platform_subscription", "Abonnement plateforme (éditeur)"),
                    ("purchase", "Achat unitaire"),
                    ("resell_right", "Achat de droit de revente"),
                    ("withdrawal", "Retrait éditeur"),
                    ("commission", "Commission plateforme"),
                    ("refund", "Remboursement"),
                ],
                max_length=50,
            ),
        ),
    ]
