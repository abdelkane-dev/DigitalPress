from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('publications', '0004_comment'),
    ]

    operations = [
        migrations.CreateModel(
            name='ReaderCategory',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=100)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('reader', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='reader_categories', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'verbose_name': 'Catégorie personnelle (Lecteur)',
                'verbose_name_plural': 'Catégories personnelles (Lecteur)',
                'ordering': ['name'],
                'unique_together': {('reader', 'name')},
            },
        ),
        migrations.CreateModel(
            name='Favorite',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('categories', models.ManyToManyField(blank=True, related_name='favorites', to='publications.readercategory')),
                ('publication', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='favorited_by', to='publications.publication')),
                ('reader', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='favorites', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'verbose_name': 'Favori',
                'verbose_name_plural': 'Favoris',
                'ordering': ['-created_at'],
                'unique_together': {('reader', 'publication')},
            },
        ),
    ]
