from django.db import migrations


def update_max_reader_plans(apps, schema_editor):
    PlatformPlan = apps.get_model('abonnements', 'PlatformPlan')

    updates = {
        'Basique': (1, "Jusqu'à 2 offres d'abonnement pour vos lecteurs", "1 offre d'abonnement pour vos lecteurs"),
        'Standard': (3, "Jusqu'à 5 offres d'abonnement pour vos lecteurs", "Jusqu'à 3 offres d'abonnement pour vos lecteurs"),
    }
    for name, (max_plans, old_line, new_line) in updates.items():
        plan = PlatformPlan.objects.filter(name=name).first()
        if not plan:
            continue
        plan.max_reader_plans = max_plans
        plan.features = plan.features.replace(old_line, new_line)
        plan.save(update_fields=['max_reader_plans', 'features'])


def reverse_noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("abonnements", "0008_platformplan_max_withdrawal"),
    ]

    operations = [
        migrations.RunPython(update_max_reader_plans, reverse_noop),
    ]
