from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('paiements', '0006_withdrawalverificationcode'),
    ]

    operations = [
        migrations.RenameField(
            model_name='transaction',
            old_name='movapay_ref',
            new_name='cinetpay_ref',
        ),
    ]
