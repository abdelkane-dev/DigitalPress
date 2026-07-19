# Generated for the "Mes Conversations" feature (remplace la page Favoris)

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
import django.utils.timezone


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('publications', '0002_alter_category_slug'),
    ]

    operations = [
        migrations.AddField(
            model_name='review',
            name='updated_at',
            field=models.DateTimeField(auto_now=True, default=django.utils.timezone.now),
            preserve_default=False,
        ),
        migrations.CreateModel(
            name='ConversationRead',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('last_read_at', models.DateTimeField(auto_now=True)),
                ('publication', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='conversation_reads', to='publications.publication')),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='conversation_reads', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'verbose_name': 'Lecture de conversation',
                'verbose_name_plural': 'Lectures de conversations',
                'unique_together': {('user', 'publication')},
            },
        ),
        migrations.CreateModel(
            name='HiddenConversation',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('hidden_at', models.DateTimeField(auto_now_add=True)),
                ('publication', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='hidden_by', to='publications.publication')),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='hidden_conversations', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'verbose_name': 'Conversation masquée',
                'verbose_name_plural': 'Conversations masquées',
                'unique_together': {('user', 'publication')},
            },
        ),
    ]
