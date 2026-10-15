from django.db import migrations


def update_features(apps, schema_editor):
    """Aligne le texte descriptif de chaque palier sur sa commission réelle
    (20/15/10 %) : le texte affiché était resté sur les anciennes valeurs
    (15/10/5) alors que le champ commission_rate était déjà corrigé — le
    frontend affichait donc une commission contradictoire avec le texte.
    """
    PlatformPlan = apps.get_model('abonnements', 'PlatformPlan')
    updates = {
        'Basique': (
            "Publications illimitées (articles, magazines, journaux, vidéos, e-books, rapports)\n"
            "Commission plateforme : 20%\n"
            "1 offre d'abonnement pour vos lecteurs\n"
            "Retrait minimum : 15 000 F\n"
            "Statistiques de base (vues, abonnés)\n"
            "Support par email\n"
            "Retrait maximum : 100 000 F"
        ),
        'Standard': (
            "Publications illimitées, tous types de contenu\n"
            "Commission plateforme réduite : 15%\n"
            "Jusqu'à 5 publications mises en avant simultanément\n"
            "Jusqu'à 3 offres d'abonnement pour vos lecteurs\n"
            "Badge « Vérifié » sur votre profil public\n"
            "Retrait minimum : 10 000 F\n"
            "Export CSV de vos statistiques\n"
            "Support prioritaire par email\n"
            "Retrait maximum : 300 000 F"
        ),
        'Premium': (
            "Publications illimitées, tous types de contenu\n"
            "Commission plateforme minimale : 10%\n"
            "Jusqu'à 10 publications mises en avant simultanément\n"
            "Offres d'abonnement illimitées pour vos lecteurs\n"
            "Badge « Vérifié » sur votre profil public\n"
            "Retrait minimum : 2 000 F\n"
            "Export CSV de vos statistiques\n"
            "Support prioritaire dédié\n"
            "Retrait maximum : 2 000 000 F"
        ),
    }
    for name, text in updates.items():
        PlatformPlan.objects.filter(name=name).update(features=text)


def reverse_noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('abonnements', '0013_alter_platformplan_options'),
    ]

    operations = [
        migrations.RunPython(update_features, reverse_noop),
    ]
