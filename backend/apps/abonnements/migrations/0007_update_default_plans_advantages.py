from django.db import migrations


def update_plans(apps, schema_editor):
    PlatformPlan = apps.get_model('abonnements', 'PlatformPlan')

    updates = {
        'Basique': {
            'commission_rate': 15.00,
            'max_reader_plans': 2,
            'has_verified_badge': False,
            'min_withdrawal_amount': 15000,
            'has_stats_export': False,
            'features': (
                "Publications illimitées (articles, magazines, journaux, vidéos, e-books, rapports)\n"
                "Commission plateforme : 15%\n"
                "Jusqu'à 2 offres d'abonnement pour vos lecteurs\n"
                "Retrait minimum : 15 000 F\n"
                "Statistiques de base (vues, abonnés)\n"
                "Support par email"
            ),
        },
        'Standard': {
            'commission_rate': 10.00,
            'max_reader_plans': 5,
            'has_verified_badge': True,
            'min_withdrawal_amount': 10000,
            'has_stats_export': True,
            'features': (
                "Publications illimitées, tous types de contenu\n"
                "Commission plateforme réduite : 10%\n"
                "Jusqu'à 5 publications mises en avant simultanément\n"
                "Jusqu'à 5 offres d'abonnement pour vos lecteurs\n"
                "Badge « Vérifié » sur votre profil public\n"
                "Retrait minimum : 10 000 F\n"
                "Export CSV de vos statistiques\n"
                "Support prioritaire par email"
            ),
        },
        'Premium': {
            'commission_rate': 5.00,
            'max_reader_plans': 0,  # illimité
            'has_verified_badge': True,
            'min_withdrawal_amount': 2000,
            'has_stats_export': True,
            'features': (
                "Publications illimitées, tous types de contenu\n"
                "Commission plateforme minimale : 5%\n"
                "Jusqu'à 10 publications mises en avant simultanément\n"
                "Offres d'abonnement illimitées pour vos lecteurs\n"
                "Badge « Vérifié » sur votre profil public\n"
                "Retrait minimum : 2 000 F\n"
                "Export CSV de vos statistiques\n"
                "Support prioritaire dédié"
            ),
        },
    }

    for name, data in updates.items():
        PlatformPlan.objects.filter(name=name).update(**data)


def reverse_noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("abonnements", "0006_platformplan_more_advantages"),
    ]

    operations = [
        migrations.RunPython(update_plans, reverse_noop),
    ]
