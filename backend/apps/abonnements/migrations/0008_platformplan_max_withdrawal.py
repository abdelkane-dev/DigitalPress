from django.db import migrations, models


def set_max_withdrawal_defaults(apps, schema_editor):
    PlatformPlan = apps.get_model('abonnements', 'PlatformPlan')
    defaults = {
        'Basique': {'max_withdrawal_amount': 100000, 'suffix': 'Retrait maximum : 100 000 F'},
        'Standard': {'max_withdrawal_amount': 300000, 'suffix': 'Retrait maximum : 300 000 F'},
        'Premium': {'max_withdrawal_amount': 2000000, 'suffix': 'Retrait maximum : 2 000 000 F'},
    }
    for name, data in defaults.items():
        plan = PlatformPlan.objects.filter(name=name).first()
        if not plan:
            continue
        plan.max_withdrawal_amount = data['max_withdrawal_amount']
        if data['suffix'] not in plan.features:
            plan.features = plan.features.rstrip() + f"\n{data['suffix']}"
        plan.save(update_fields=['max_withdrawal_amount', 'features'])


def reverse_noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("abonnements", "0007_update_default_plans_advantages"),
    ]

    operations = [
        migrations.AddField(
            model_name="platformplan",
            name="max_withdrawal_amount",
            field=models.DecimalField(
                decimal_places=2, default=500000, max_digits=10,
                help_text="Montant maximum autorisé par demande de retrait — plus haut = plus de flexibilité",
            ),
        ),
        migrations.RunPython(set_max_withdrawal_defaults, reverse_noop),
    ]
