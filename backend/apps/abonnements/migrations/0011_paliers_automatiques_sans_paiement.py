from django.db import migrations, models


def update_plans(apps, schema_editor):
    PlatformPlan = apps.get_model('abonnements', 'PlatformPlan')

    # Seuils de progression automatique (voir document de spécifications) :
    # Basique -> Standard -> Premium selon nb d'abonnés / publications / ventes.
    # Les prix ne servent plus à rien : la plateforme ne se rémunère que
    # via la commission sur les ventes, jamais via un abonnement payant.
    updates = {
        'Basique': {
            'prix': 0,
            'commission_rate': 20.00,
            'min_subscribers': 0,
            'min_publications': 0,
            'min_sales': 0,
            'description': "Palier de départ : toutes les fonctionnalités de publication, sans restriction.",
        },
        'Standard': {
            'prix': 0,
            'commission_rate': 15.00,
            'min_subscribers': 1001,
            'min_publications': 61,
            'min_sales': 251,
            'description': "Palier atteint automatiquement en gagnant en audience et en activité.",
        },
        'Premium': {
            'prix': 0,
            'commission_rate': 10.00,
            'min_subscribers': 2001,
            'min_publications': 121,
            'min_sales': 501,
            'description': "Palier le plus avancé, débloqué automatiquement par votre activité.",
        },
    }
    for name, data in updates.items():
        PlatformPlan.objects.filter(name=name).update(**data)


def reverse_noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("abonnements", "0010_alter_platformplan_features"),
    ]

    operations = [
        migrations.AddField(
            model_name="platformplan",
            name="min_subscribers",
            field=models.PositiveIntegerField(
                default=0,
                help_text="Nombre d'abonnés à atteindre pour accéder automatiquement à ce palier (0 = palier de départ)",
            ),
        ),
        migrations.AddField(
            model_name="platformplan",
            name="min_publications",
            field=models.PositiveIntegerField(
                default=0,
                help_text="Nombre de publications à atteindre pour accéder automatiquement à ce palier",
            ),
        ),
        migrations.AddField(
            model_name="platformplan",
            name="min_sales",
            field=models.PositiveIntegerField(
                default=0,
                help_text="Nombre de ventes à atteindre pour accéder automatiquement à ce palier",
            ),
        ),
        migrations.AlterField(
            model_name="platformplan",
            name="prix",
            field=models.DecimalField(
                decimal_places=2, default=0, max_digits=10,
                help_text="Obsolète : la plateforme ne se rémunère plus que via la commission sur les ventes. Toujours 0.",
            ),
        ),
        migrations.RunPython(update_plans, reverse_noop),
    ]
