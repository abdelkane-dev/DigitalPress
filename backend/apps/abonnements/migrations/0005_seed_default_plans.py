from django.db import migrations


def create_default_plans(apps, schema_editor):
    PlatformPlan = apps.get_model('abonnements', 'PlatformPlan')

    # Aucune restriction sur le nombre de publications ni sur le type de
    # contenu (vidéo compris) : ce sont des fonctionnalités déjà
    # existantes de la plateforme, accessibles à tout éditeur quel que
    # soit son plan — un petit journal a les mêmes droits de publication
    # qu'une grande agence de presse. Le seul avantage réel apporté par un
    # plan supérieur est le nombre de publications qu'il peut mettre en
    # avant (meilleur classement dans les listes publiques).
    plans = [
        {
            'name': 'Basique',
            'description': "Pour démarrer : toutes les fonctionnalités de publication, sans restriction.",
            'prix': 5000,
            'period': 'monthly',
            'max_priority_slots': 0,
            'features': (
                "Publications illimitées (articles, magazines, journaux, vidéos, e-books, rapports)\n"
                "Statistiques de base (vues, abonnés)\n"
                "Support par email"
            ),
        },
        {
            'name': 'Standard',
            'description': "Pour les éditeurs qui veulent gagner en visibilité.",
            'prix': 15000,
            'period': 'monthly',
            'max_priority_slots': 5,
            'features': (
                "Publications illimitées, tous types de contenu\n"
                "Jusqu'à 5 publications mises en avant simultanément\n"
                "Statistiques avancées\n"
                "Support prioritaire par email"
            ),
        },
        {
            'name': 'Premium',
            'description': "Pour une visibilité maximale sur la plateforme.",
            'prix': 35000,
            'period': 'monthly',
            'max_priority_slots': 10,
            'features': (
                "Publications illimitées, tous types de contenu\n"
                "Jusqu'à 10 publications mises en avant simultanément\n"
                "Statistiques avancées\n"
                "Support prioritaire dédié"
            ),
        },
    ]

    for data in plans:
        PlatformPlan.objects.get_or_create(name=data['name'], defaults=data)


def remove_default_plans(apps, schema_editor):
    PlatformPlan = apps.get_model('abonnements', 'PlatformPlan')
    PlatformPlan.objects.filter(name__in=['Basique', 'Standard', 'Premium']).delete()


class Migration(migrations.Migration):

    dependencies = [
        ("abonnements", "0004_platformplan_restrictions"),
    ]

    operations = [
        migrations.RunPython(create_default_plans, remove_default_plans),
    ]
