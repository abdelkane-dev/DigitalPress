from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("publications", "0009_publication_is_featured"),
    ]

    operations = [
        migrations.AddField(
            model_name="publication",
            name="is_subscriber_exclusive",
            field=models.BooleanField(
                default=False,
                help_text="Réservé exclusivement aux lecteurs abonnés à cet éditeur — "
                          "non achetable à l'unité, contrairement au contenu payant normal "
                          "(voir Publication.is_accessible_by).",
            ),
        ),
    ]
