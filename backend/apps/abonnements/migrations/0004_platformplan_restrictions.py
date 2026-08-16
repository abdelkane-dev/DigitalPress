from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("abonnements", "0003_platform_subscription"),
    ]

    operations = [
        migrations.AddField(
            model_name="platformplan",
            name="max_priority_slots",
            field=models.PositiveIntegerField(
                default=0,
                help_text="Nombre de publications que l'éditeur peut mettre en avant simultanément",
            ),
        ),
    ]
