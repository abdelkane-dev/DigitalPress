from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("notifications", "0002_alter_notification_type_notif"),
    ]

    operations = [
        migrations.AlterField(
            model_name="notification",
            name="type_notif",
            field=models.CharField(
                choices=[
                    ("payment_success", "Paiement réussi"),
                    ("payment_failed", "Paiement échoué"),
                    ("subscription_activated", "Abonnement activé"),
                    ("subscription_expired", "Abonnement expiré"),
                    ("withdrawal_approved", "Retrait approuvé"),
                    ("withdrawal_rejected", "Retrait rejeté"),
                    ("withdrawal_completed", "Retrait complété"),
                    ("new_publication", "Nouvelle publication"),
                    ("new_comment", "Nouveau commentaire"),
                    ("new_reply", "Nouvelle réponse"),
                    ("verification_submitted", "Vérification éditeur soumise"),
                    ("verification_reviewed", "Vérification éditeur traitée"),
                    ("system", "Système"),
                ],
                default="system",
                max_length=30,
            ),
        ),
    ]
