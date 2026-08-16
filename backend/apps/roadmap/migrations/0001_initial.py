from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='FeatureItem',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('title', models.CharField(max_length=150)),
                ('description', models.TextField(blank=True)),
                ('scope', models.CharField(choices=[('admin', 'Admin uniquement'), ('publisher', 'Éditeur uniquement'), ('both', 'Admin et Éditeur')], default='both', max_length=20)),
                ('status', models.CharField(choices=[('a_venir', 'À venir'), ('en_cours', 'En cours de développement'), ('fait', 'Réalisé'), ('rejete', 'Non retenu')], default='a_venir', max_length=20)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('created_by', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='suggested_features', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'verbose_name': 'Fonctionnalité à venir',
                'verbose_name_plural': 'Fonctionnalités à venir',
                'ordering': ['status', '-created_at'],
            },
        ),
    ]
