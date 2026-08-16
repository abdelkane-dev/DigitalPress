from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("publications", "0008_publication_original_publication_and_more"),
    ]

    operations = [
        migrations.AddField(
            model_name="publication",
            name="is_featured",
            field=models.BooleanField(
                default=False,
                help_text="Mise en avant dans les listes publiques — avantage réel selon le plan plateforme de l'éditeur",
            ),
        ),
    ]
